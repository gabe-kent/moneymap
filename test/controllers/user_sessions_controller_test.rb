require "test_helper"

class UserSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    sign_in_as @user
  end

  test "destroy of the current session signs the user out" do
    delete user_session_path(Current.session)

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "destroy of another of the user's sessions revokes it without signing the current one out" do
    other_session = @user.sessions.create!

    assert_difference -> { @user.sessions.count }, -1 do
      delete user_session_path(other_session)
    end

    assert_redirected_to edit_settings_path
    assert cookies[:session_id].present?
  end

  test "destroy on another user's session is not found" do
    other_users_session = @other_user.sessions.create!

    assert_no_difference -> { Session.count } do
      delete user_session_path(other_users_session)
    end

    assert_response :not_found
  end

  test "destroy_all revokes every session but the current one" do
    @user.sessions.create!
    @user.sessions.create!

    assert_difference -> { @user.sessions.count }, -2 do
      delete destroy_all_user_sessions_path
    end

    assert_redirected_to edit_settings_path
    assert cookies[:session_id].present?
  end
end
