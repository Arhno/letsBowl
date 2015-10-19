require 'test_helper'

class GameControllerTest < ActionController::TestCase
  test "should get extract" do
    get :extract
    assert_response :success
  end

end
