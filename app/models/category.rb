class Category < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :restrict_with_error
  has_many :budgets, dependent: :destroy

  enum :kind, {
    income: "income",
    expense: "expense"
  }

  enum :color, {
    red: "red",
    orange: "orange",
    yellow: "yellow",
    green: "green",
    teal: "teal",
    blue: "blue",
    purple: "purple",
    pink: "pink"
  }

  # The swatch each enum colour renders as, and the single source of truth for
  # it. Charts (donut slices, SVG fills, bar fills) need the literal value rather
  # than a utility class, so swatches are drawn from this everywhere rather than
  # from a parallel set of Tailwind classes.
  COLOR_HEX = {
    "red" => "#CF2519",
    "orange" => "#D98E3B",
    "yellow" => "#E8B93F",
    "green" => "#00B388",
    "teal" => "#1C8F7A",
    "blue" => "#5E74E3",
    "purple" => "#E7ADFF",
    "pink" => "#E88FB0"
  }.freeze

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :kind, presence: true
  validates :color, presence: true

  def hex_color
    COLOR_HEX.fetch(color, "#A9B2B0")
  end
end
