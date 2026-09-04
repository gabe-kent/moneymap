require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  test "shows the footer" do
    visit root_path

    assert_text "Moneymap — built with Rails 8 + DaisyUI"
  end
end
