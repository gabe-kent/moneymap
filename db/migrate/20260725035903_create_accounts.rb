class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false
      t.integer :starting_balance_cents, null: false, default: 0

      t.timestamps
    end
  end
end
