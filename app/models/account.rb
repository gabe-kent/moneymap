class Account < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :restrict_with_error

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

  def current_balance
    Money.new(starting_balance_cents + transactions.sum(:amount_cents), "USD")
  end
end
