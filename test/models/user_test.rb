require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "seeds default categories after creation" do
    user = User.create!(email_address: "new-user@example.com", password: "password")
    assert_equal 8, user.categories.count
  end
end
