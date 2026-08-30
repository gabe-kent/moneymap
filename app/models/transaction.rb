class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :account
  belongs_to :category, optional: true

  monetize :amount_cents

  enum :txn_type, {
    income: "income",
    expense: "expense",
    transfer: "transfer"
  }

  before_validation :apply_sign_convention

  validates :occurred_on, presence: true
  validates :txn_type, presence: true
  validates :amount_cents, presence: true
  validate :account_belongs_to_user
  validate :category_belongs_to_user
  validate :category_kind_matches_txn_type

  private
    def apply_sign_convention
      return if amount_cents.blank? || transfer?
      self.amount_cents = income? ? amount_cents.abs : -amount_cents.abs
    end

    def account_belongs_to_user
      errors.add(:account, "must belong to you") if account && account.user_id != user_id
    end

    def category_belongs_to_user
      errors.add(:category, "must belong to you") if category && category.user_id != user_id
    end

    def category_kind_matches_txn_type
      return if category.blank? || txn_type.blank?
      errors.add(:category, "kind must match transaction type") if category.kind != txn_type
    end
end
