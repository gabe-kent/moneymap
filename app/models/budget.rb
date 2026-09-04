# A spending target for one expense category in one calendar month.
#
# `month` is always normalized to the first of the month, so a budget is
# addressed by (user, category, month) and the unique index can enforce
# "one target per category per month".
class Budget < ApplicationRecord
  belongs_to :user
  belongs_to :category

  monetize :target_cents

  before_validation :normalize_month

  validates :month, presence: true
  validates :target_cents, presence: true, numericality: { greater_than: 0 }
  validates :category_id, uniqueness: { scope: %i[ user_id month ], message: "already has a budget this month" }
  validate :category_belongs_to_user
  validate :category_is_an_expense

  scope :for_month, ->(month) { where(month: month.beginning_of_month) }

  private
    def normalize_month
      self.month = month.beginning_of_month if month.present?
    end

    def category_belongs_to_user
      errors.add(:category, "must belong to you") if category && category.user_id != user_id
    end

    def category_is_an_expense
      errors.add(:category, "must be an expense category") if category && !category.expense?
    end
end
