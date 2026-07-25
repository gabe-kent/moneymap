class Account < ApplicationRecord
  belongs_to :user

  monetize :starting_balance_cents

  enum :kind, {
    checking: "checking",
    savings: "savings",
    cash: "cash",
    credit: "credit",
    investment: "investment"
  }

  validates :name, presence: true
  validates :kind, presence: true
  validates :starting_balance_cents, presence: true
end
