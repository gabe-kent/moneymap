require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "valid with name, kind, color, and user" do
    category = @user.categories.build(name: "Groceries", kind: "expense", color: "orange")
    assert category.valid?
  end

  test "invalid without a name" do
    category = @user.categories.build(kind: "expense", color: "orange")
    assert_not category.valid?
    assert_includes category.errors[:name], "can't be blank"
  end

  test "invalid without a kind" do
    category = @user.categories.build(name: "Groceries", color: "orange")
    assert_not category.valid?
    assert_includes category.errors[:kind], "can't be blank"
  end

  test "invalid without a color" do
    category = @user.categories.build(name: "Groceries", kind: "expense")
    assert_not category.valid?
    assert_includes category.errors[:color], "can't be blank"
  end

  test "raises on a kind outside the fixed list" do
    category = @user.categories.build(name: "Groceries", color: "orange")
    assert_raises(ArgumentError) { category.kind = "bogus" }
  end

  test "raises on a color outside the fixed list" do
    category = @user.categories.build(name: "Groceries", kind: "expense")
    assert_raises(ArgumentError) { category.color = "chartreuse" }
  end

  test "invalid with a duplicate name for the same user" do
    @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    duplicate = @user.categories.build(name: "Groceries", kind: "expense", color: "blue")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "invalid with a case-insensitive duplicate name for the same user" do
    @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    duplicate = @user.categories.build(name: "GROCERIES", kind: "expense", color: "blue")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "allows the same name for different users" do
    @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    other_user = users(:two)

    category = other_user.categories.build(name: "Groceries", kind: "expense", color: "blue")

    assert category.valid?
  end

  test "requires a user" do
    category = Category.new(name: "Groceries", kind: "expense", color: "orange")
    assert_not category.valid?
    assert_includes category.errors[:user], "must exist"
  end

  test "destroying a user destroys their categories" do
    category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    assert_difference -> { Category.count }, -1 do
      @user.destroy
    end
    assert_not Category.exists?(category.id)
  end
end
