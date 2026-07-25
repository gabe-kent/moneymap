class Category < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :restrict_with_error

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

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :kind, presence: true
  validates :color, presence: true
end
