class FeatureFlag < ApplicationRecord
  # Placeholders for the upcoming dashboard/budgets work (see docs/repo-review-2026-08-29.md) —
  # add a key here before creating a FeatureFlag row with it.
  REGISTRY = %w[budgets dashboard].freeze

  has_many :feature_flag_assignments, dependent: :destroy
  has_many :users, through: :feature_flag_assignments

  validates :key, presence: true, uniqueness: true, inclusion: { in: REGISTRY }

  def self.enabled?(key, user: nil)
    FeatureFlagCheck.new(key, user: user).call
  end
end
