class FeatureFlagAssignment < ApplicationRecord
  belongs_to :feature_flag
  belongs_to :user

  validates :user_id, uniqueness: { scope: :feature_flag_id }
end
