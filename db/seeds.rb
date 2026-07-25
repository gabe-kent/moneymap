# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Only User exists as a domain model so far (see CLAUDE.md — no budgeting/finance features yet).
# A couple of sample logins so dev/demo environments aren't empty.
[
  "demo@moneymap.test",
  "alex@moneymap.test"
].each do |email_address|
  User.find_or_create_by!(email_address: email_address) do |user|
    user.password = "password123"
  end
end

# Personal login, opt-in via env vars set in the Render dashboard (there's no self-serve
# sign-up yet, and SSH/console access isn't available on the free plan). Only sets the
# password on creation, so re-running this after changing SEED_ADMIN_PASSWORD won't
# silently reset an already-created account.
if ENV["SEED_ADMIN_EMAIL"].present? && ENV["SEED_ADMIN_PASSWORD"].present?
  User.find_or_create_by!(email_address: ENV["SEED_ADMIN_EMAIL"]) do |user|
    user.password = ENV["SEED_ADMIN_PASSWORD"]
  end
end

puts "Seeded #{User.count} user(s)."
