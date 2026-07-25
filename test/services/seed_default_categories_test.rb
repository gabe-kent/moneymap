require "test_helper"

class SeedDefaultCategoriesTest < ActiveSupport::TestCase
  test "creates the 8 default categories for the user" do
    user = users(:one)

    assert_difference -> { user.categories.count }, 8 do
      SeedDefaultCategories.new(user).call
    end
  end

  test "creates categories with the correct name, kind, and color" do
    user = users(:one)
    SeedDefaultCategories.new(user).call

    expected = {
      "Salary" => %w[income green],
      "Other Income" => %w[income teal],
      "Groceries" => %w[expense orange],
      "Rent" => %w[expense red],
      "Utilities" => %w[expense blue],
      "Transportation" => %w[expense purple],
      "Entertainment" => %w[expense pink],
      "Dining Out" => %w[expense yellow]
    }

    expected.each do |name, (kind, color)|
      category = user.categories.find_by(name: name)
      assert category, "expected a category named #{name.inspect}"
      assert_equal kind, category.kind
      assert_equal color, category.color
    end
  end
end
