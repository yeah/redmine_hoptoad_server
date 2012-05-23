require File.dirname(__FILE__) + '/../test_helper'

class NoticesControllerTest < ActionController::TestCase
  fixtures :projects, :users, :trackers, :projects_trackers

  def setup
    Setting.mail_handler_api_key = 'asdfghjk'
    @project = Project.find :first
    @tracker = @project.trackers.first
  end

  test 'should create an issue with journal entry' do
    assert_difference "Issue.count", 1 do
      assert_difference "Journal.count", 1 do
        raw_post :index_v2, {}, create_error.to_xml
      end
    end
    assert_response :success
    assert issue = Issue.find(:first,
                              :conditions => "subject like 'RuntimeError in vendor/plugins/redmine_hoptoad_server/test/functional/notices_controller_test.rb%'")
    assert_equal(1, issue.journals.size)
    assert occurences_field = IssueCustomField.find_by_name('# Occurences')
    assert occurences_value = issue.custom_value_for(occurences_field)
    assert_equal('1', occurences_value.value)


    assert_no_difference 'Issue.count' do
      assert_difference "Journal.count", 1 do
        raw_post :index_v2, {}, create_error.to_xml
      end
    end
    occurences_value.reload
    assert_equal('2', occurences_value.value)
  end

  test "should render 404 for non existing project" do
    assert_no_difference "Issue.count" do
      assert_no_difference "Journal.count" do
        raw_post :index_v2, {}, create_error(:project => 'Unknown').to_xml
      end
    end
    assert_response 404
  end

  test "should render 404 for non existing tracker" do
    assert_no_difference "Issue.count" do
      assert_no_difference "Journal.count" do
        raw_post :index_v2, {}, create_error(:tracker => 'Unknown').to_xml
      end
    end
    assert_response 404
  end


  def create_error(options = {})
    raise 'test'
  rescue
    return Airbrake.send(:build_notice_for,
                         $!,
                         :api_key => {
                           :project => @project.identifier,
                           :tracker => @tracker.name,
                           :api_key => 'asdfghjk',
                           :priority => 5
                         }.merge(options).to_yaml)
  end
end
