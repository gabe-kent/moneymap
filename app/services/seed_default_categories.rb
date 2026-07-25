class SeedDefaultCategories
  DEFAULTS = [
    { name: "Salary", kind: "income", color: "green" },
    { name: "Other Income", kind: "income", color: "teal" },
    { name: "Groceries", kind: "expense", color: "orange" },
    { name: "Rent", kind: "expense", color: "red" },
    { name: "Utilities", kind: "expense", color: "blue" },
    { name: "Transportation", kind: "expense", color: "purple" },
    { name: "Entertainment", kind: "expense", color: "pink" },
    { name: "Dining Out", kind: "expense", color: "yellow" }
  ].freeze

  def initialize(user)
    @user = user
  end

  def call
    DEFAULTS.each do |attributes|
      @user.categories.create!(attributes)
    end
  end
end
