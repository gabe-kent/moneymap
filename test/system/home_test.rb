require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  test "shows the signed-out landing page" do
    visit root_path

    assert_text "moneymap"
    assert_text "See where your money goes"
    assert_link "Sign in"
  end
end
