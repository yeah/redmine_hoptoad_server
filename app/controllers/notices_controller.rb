require 'pp'

class NoticesController < ActionController::Base

  before_filter :check_enabled
  before_filter :find_or_create_custom_fields

  unloadable

  TRACE_FILTERS = [
    /^On\sline\s#\d+\sof/,
    /^\d+:/
  ]

  def create_v2
    #logger.debug {"received v2 request:\n#{@notice.inspect}\nwith redmine_params:\n#{@redmine_params.inspect}"}
    create_or_update_issue @redmine_params, @notice
  end

  def create
    #logger.debug {"received v1 request:\n#{@notice.inspect}\nwith redmine_params:\n#{@redmine_params.inspect}"}
    notice = v2_notice_hash(@notice)
    #logger.debug {"transformed arguments:\n#{notice.inspect}"}
    create_or_update_issue @redmine_params, notice
  end

  private

  def create_or_update_issue(redmine_params, notice)
    # retrieve redmine objects referenced in redmine_params

    # project
    unless project = Project.find_by_identifier(redmine_params["project"])
      msg = "could not log error, project #{redmine_params["project"]} not found."
      Rails.logger.error msg
      render :text => msg, :status => 404 and return
    end

    # tracker
    unless tracker = project.trackers.find_by_name(redmine_params["tracker"])
      msg = "could not log error, tracker #{redmine_params["tracker"]} not found."
      Rails.logger.error msg
      render :text => msg, :status => 404 and return
    end

    # user
    author = User.find_by_login(redmine_params["author"]) || User.anonymous

    # error class and message
    error_class = notice['error']['class'].to_s
    error_message = notice['error']['message']

    # build filtered backtrace
    backtrace = notice['error']['backtrace'] rescue []
    filtered_backtrace = filter_backtrace project, backtrace
    error_line = filtered_backtrace.first

    # build subject by removing method name and '[RAILS_ROOT]', make sure it fits in a varchar
    subject = redmine_params["environment"] ? "[#{redmine_params["environment"]}] " : ""
    subject << error_class
    subject << " in #{cleanup_path( error_line['file'] )[0,(250-subject.length)]}:#{error_line['number']}" if error_line

    # build description including a link to source repository
    description = "Redmine Notifier reported an Error"
    unless filtered_backtrace.blank?
      repo_root = redmine_params["repository_root"]
      repo_root ||= project.custom_value_for(@repository_root_field).value.gsub(/\/$/,'') rescue nil
      description << " related to source:#{repo_root}/#{cleanup_path error_line['file']}#L#{error_line['number']}"
    end

    issue = Issue.find_by_subject_and_project_id_and_tracker_id_and_author_id(subject, project.id, tracker.id, author.id)
    if issue.nil?
      # new issue
      issue = Issue.new(:subject => subject, :project_id => project.id, :tracker_id => tracker.id, :author_id => author.id)

      # set standard redmine issue fields
      issue.category = IssueCategory.find_by_name(redmine_params["category"]) unless redmine_params["category"].blank?
      issue.assigned_to = (User.find_by_login(redmine_params["assigned_to"]) || Group.find_by_lastname(redmine_params["assigned_to"])) unless redmine_params["assigned_to"].blank?
      issue.priority_id = redmine_params["priority"].blank? ?
        IssuePriority.default.id :
        redmine_params["priority"]
      issue.description = description

      ensure_project_has_fields(project)
      ensure_tracker_has_fields(tracker)

      # set custom field error class
      cf_values = { @error_class_field.id => error_class,
                    @occurences_field.id => 1 }
      unless redmine_params["environment"].blank?
        cf_values[@environment_field.id] = redmine_params["environment"]
      end
      issue.custom_field_values = cf_values
      issue.skip_notification = true
      issue.save!
    else
      # increment occurences custom field
      if value = issue.custom_value_for(@occurences_field)
        value.update_attribute :value, (value.value.to_i + 1).to_s
      else
        issue.custom_values.create!(:value => 1, :custom_field => @occurences_field)
      end
    end


    # create the journal entry, update issue attributes
    retried_once = false # we retry once in case of a StaleObjectError
    begin
      issue = Issue.find issue.id # otherwise the save below resets the custom value from above. Also should reduce the chance to run into the staleobject problem.
      # update journal
      text = "h4. Error message\n\n<pre>#{error_message}</pre>"
      text << "\n\nh4. Filtered backtrace\n\n<pre>#{format_backtrace(filtered_backtrace)}</pre>" unless filtered_backtrace.blank?
      text << "\n\nh4. Request\n\n<pre>#{format_hash notice['request']}</pre>" unless notice['request'].blank?
      text << "\n\nh4. Session\n\n<pre>#{format_hash notice['session']}</pre>" unless notice['session'].blank?
      unless (env = (notice['server_environment'] || notice['environment'])).blank?
        text << "\n\nh4. Environment\n\n<pre>#{format_hash env}</pre>"
      end
      text << "\n\nh4. Full backtrace\n\n<pre>#{format_backtrace backtrace}</pre>" unless backtrace.blank?
      journal = issue.init_journal author, text

      # reopen issue if needed
      if issue.status.blank? or issue.status.is_closed?
        issue.status = issue.tracker.default_status
      end

      issue.save!
    rescue ActiveRecord::StaleObjectError
      if retried_once
        Rails.logger.error "airbrake server: failed to update issue #{issue.id} for the second time, giving up."
      else
        retried_once = true
        retry
      end
    end
    render :status => 200, :text => "Received bug report.\n<error-id>#{issue.id}</error-id>\n<id>#{issue.id}</id>" # newer Airbrake expects just <id>...
  end

  def format_hash(hash)
    PP.pp hash, ""
  end

  # transforms the old-style notice structure into the hoptoad v2 data format
  def v2_notice_hash(notice)
    {
      'error' => {
        'class' => notice['error_class'],
        'message' => notice['error_message'],
        'backtrace' => parse_backtrace(notice['back'].blank? ? notice['backtrace'] : notice['back'])
      },
      'environment' => (notice['server_environment'].blank? ? notice['environment'] : notice['server_environment']),
      'session' => notice['session'],
      'request' => notice['request']
    }
  end

  def parse_backtrace(lines)
    lines.map do |line|
      if line =~ /(.+):(\d+)(:in `(.+)')?/
        { 'number' => $2.to_i, 'method' => $4, 'file' => $1 }
      else
        logger.error "could not parse backtrace line:\n#{line}"
        nil
      end
    end.compact
  end

  def filter_backtrace(project, backtrace)
    project_trace_filters = project.custom_value_for(@trace_filter_field).value.split(/[,\s\n\r]+/) rescue []
    backtrace.reject do |line|
      file = line['file'] rescue nil
      if file
        (TRACE_FILTERS + project_trace_filters).map do |filter|
          file.scan(filter)
        end.flatten.compact.uniq.any?
      else
        Rails.logger.error "invalid backtrace element #{line.inspect}"
        true
      end
    end
  end

  def format_backtrace(lines)
    lines.map{ |line| "#{line['file']}:#{line['number']}#{":in #{line['method']}" if line['method']}" }.join("\n")
  end

  def cleanup_path(path)
    path.gsub(/\[(PROJECT|RAILS)_ROOT\]\//,'')
  end

  # before_filter, checks api key and parses request
  def check_enabled
    User.current = nil
    parse_request
    unless @api_key.present? and @api_key == Setting.mail_handler_api_key
      render :text => 'Access denied. Redmine API is disabled or key is invalid.', :status => 403
      false
    end
  end

  def parse_request
    logger.debug { "hoptoad error notification:\n#{request.raw_post}" }
    case params[:action]
    when 'create_v2'
      if defined?(Nokogiri)
        @notice = HoptoadV2Notice.new request.raw_post
        @redmine_params = @notice.redmine_params
      else
        # falling back to using the request body as parsed by rails.
        # this leads to sub-optimal results for request and session info.
        @notice = params[:notice]
        @notice['error']['backtrace'] = @notice['error']['backtrace']['line']
        @redmine_params = YAML.load(@notice['api_key'], :safe => true)
      end
    when 'create'
      @notice = YAML.load(request.raw_post, :safe => true)['notice']
      @redmine_params = YAML.load(@notice['api_key'], :safe => true)
    else
      raise 'unknown action'
    end
    @redmine_params = @redmine_params.inject({}) do |parameters, (k, v)|
      parameters[k.to_s.gsub(/^:/, "")] = v
      parameters
    end

    @api_key = @redmine_params["api_key"]
    true
  end

  # make sure the custom fields exist, and load them for further usage
  def find_or_create_custom_fields
    @error_class_field = IssueCustomField.where(name: 'Error class').first_or_initialize
    if @error_class_field.new_record?
      @error_class_field.attributes = {:field_format => 'string', :searchable => true, :is_filter => true}
      @error_class_field.save(:validate => false)
    end

    @occurences_field = IssueCustomField.where(name: '# Occurences').first_or_initialize
    if @occurences_field.new_record?
      @occurences_field.attributes = {:field_format => 'int', :default_value => '0', :is_filter => true}
      @occurences_field.save(:validate => false)
    end

    @environment_field = IssueCustomField.where(name: 'Environment').first_or_initialize
    if @environment_field.new_record?
      @environment_field.attributes = {:field_format => 'string', :searchable => true, :is_filter => true}
      @environment_field.save(:validate => false)
    end

    @trace_filter_field = ProjectCustomField.where(name: 'Backtrace filter').first_or_initialize
    if @trace_filter_field.new_record?
      @trace_filter_field.attributes = {:field_format => 'text'}
      @trace_filter_field.save(:validate => false)
    end

    @repository_root_field = ProjectCustomField.where(name: 'Repository root').first_or_initialize
    if @repository_root_field.new_record?
      @repository_root_field.attributes = {:field_format => 'string'}
      @repository_root_field.save(:validate => false)
    end
  end

  # make sure that custom fields are associated to this project and tracker
  def ensure_tracker_has_fields(tracker)
    tracker.custom_fields << @error_class_field unless tracker.custom_fields.include?(@error_class_field)
    tracker.custom_fields << @occurences_field unless tracker.custom_fields.include?(@occurences_field)
    tracker.custom_fields << @environment_field unless tracker.custom_fields.include?(@environment_field)
  end

  # make sure that custom fields are associated to this project and tracker
  def ensure_project_has_fields(project)
    project.issue_custom_fields << @error_class_field unless project.issue_custom_fields.include?(@error_class_field)
    project.issue_custom_fields << @occurences_field unless project.issue_custom_fields.include?(@occurences_field)
    project.issue_custom_fields << @environment_field unless project.issue_custom_fields.include?(@environment_field)
  end

end
