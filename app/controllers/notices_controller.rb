class NoticesController < ApplicationController
  before_filter :check_if_login_required, :except => 'index'
  unloadable  
  def index
    notice = YAML.load(request.raw_post)['notice']
    redmine_params = YAML.load(notice['api_key'])
    
    if authorized = Setting.mail_handler_api_key == redmine_params[:api_key]
      
      project = Project.find_by_identifier(redmine_params[:project])
      tracker = project.trackers.find_by_name(redmine_params[:tracker])
      author = User.anonymous

      issue = Issue.find_or_initialize_by_subject_and_project_id_and_tracker_id_and_author_id_and_description(notice['error_message'],
                                                                                                              project.id,
                                                                                                              tracker.id,
                                                                                                              author.id,
                                                                                                              'Hoptoad Issue')
                                                                                                              
      if issue.new_record?
        issue.category = IssueCategory.find_by_name(redmine_params[:category]) unless redmine_params[:category].blank?
        issue.assigned_to = User.find_by_login(redmine_params[:assigned_to]) unless redmine_params[:assigned_to].blank?
        issue.priority_id = redmine_params[:priority] unless redmine_params[:priority].blank?
      end

      issue.save!

      journal = issue.init_journal(author, "h4. Backtrace\n\n<pre>#{notice['back'].to_yaml}</pre>\n\n" +
                                   "h4. Request\n\n<pre>#{notice['request'].to_yaml}</pre>\n\n" +
                                   "h4. Session\n\n<pre>#{notice['session'].to_yaml}</pre>\n\n" +
                                   "h4. Environment\n\n<pre>#{notice['environment'].to_yaml}</pre>")

      if issue.status.blank? or issue.status.is_closed?                                                                                                        
        issue.status = IssueStatus.find(:first, :conditions => {:is_default => true}, :order => 'position ASC')
      end


      issue.save!

      if issue.new_record?
        Mailer.deliver_issue_add(issue) if Setting.notified_events.include?('issue_added')
      else
        Mailer.deliver_issue_edit(journal) if Setting.notified_events.include?('issue_updated')
      end
      
      render :status => 200, :text => "Received bug report. Created/updated issue #{issue.id}."
    else
      logger.info 'Unauthorized Hoptoad API request.'
      render :status => 403, :text => 'You provided a wrong or no Redmine API key.'
    end
  end
end
