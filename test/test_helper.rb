# Load the normal Rails helper
require File.expand_path(File.dirname(__FILE__) + '/../../../../test/test_helper')

# Ensure that we are using the temporary fixture path
Engines::Testing.set_fixture_path

class ActionController::TestCase

  def raw_post(action, params, body = '')
    @request.env['RAW_POST_DATA'] = body
    response = post(action, params)
    @request.env.delete('RAW_POST_DATA')
    response
  end

end
