class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :budgets, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  after_create :seed_default_categories

  private
    def seed_default_categories
      SeedDefaultCategories.new(self).call
    end
end
