require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    sign_in_as @user
  end

  test "index lists only the current user's categories" do
    other_category = @other_user.categories.create!(name: "Their Rent", kind: "expense", color: "red")

    get categories_path

    assert_response :success
    assert_includes response.body, @category.name
    assert_not_includes response.body, other_category.name
  end

  test "index renders the category's color as a literal Tailwind class" do
    get categories_path

    assert_response :success
    assert_includes response.body, "bg-orange-500"
  end

  test "new renders the form" do
    get new_category_path
    assert_response :success
  end

  test "create with valid params" do
    assert_difference -> { @user.categories.count }, 1 do
      post categories_path, params: { category: { name: "Salary", kind: "income", color: "green" } }
    end

    assert_redirected_to categories_path
  end

  test "create with invalid params re-renders the form" do
    assert_no_difference -> { Category.count } do
      post categories_path, params: { category: { name: "", kind: "income", color: "green" } }
    end

    assert_response :unprocessable_entity
  end

  test "create with a duplicate name re-renders the form" do
    assert_no_difference -> { Category.count } do
      post categories_path, params: { category: { name: "Groceries", kind: "expense", color: "blue" } }
    end

    assert_response :unprocessable_entity
  end

  test "edit renders the form for the current user's category" do
    get edit_category_path(@category)
    assert_response :success
  end

  test "edit on another user's category is not found" do
    other_category = @other_user.categories.create!(name: "Their Rent", kind: "expense", color: "red")

    get edit_category_path(other_category)

    assert_response :not_found
  end

  test "update with valid params" do
    patch category_path(@category), params: { category: { name: "Updated Name" } }

    assert_redirected_to categories_path
    assert_equal "Updated Name", @category.reload.name
  end

  test "update on another user's category is not found" do
    other_category = @other_user.categories.create!(name: "Their Rent", kind: "expense", color: "red")

    patch category_path(other_category), params: { category: { name: "Hijacked" } }

    assert_response :not_found
    assert_not_equal "Hijacked", other_category.reload.name
  end

  test "destroy removes the category" do
    assert_difference -> { Category.count }, -1 do
      delete category_path(@category)
    end

    assert_redirected_to categories_path
  end

  test "destroy on another user's category is not found" do
    other_category = @other_user.categories.create!(name: "Their Rent", kind: "expense", color: "red")

    assert_no_difference -> { Category.count } do
      delete category_path(other_category)
    end

    assert_response :not_found
  end

  test "destroy fails and shows an error when the category has transactions" do
    account = @user.accounts.create!(name: "Checking", kind: "checking")
    @category.transactions.create!(user: @user, account: account, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

    assert_no_difference -> { Category.count } do
      delete category_path(@category)
    end

    assert_redirected_to categories_path
    follow_redirect!
    assert_includes response.body, "Cannot delete"
  end
end
