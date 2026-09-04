class CreateBudgets < ActiveRecord::Migration[8.1]
  def change
    create_table :budgets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.date :month, null: false
      t.integer :target_cents, null: false, default: 0

      t.timestamps
    end

    add_index :budgets, %i[ user_id category_id month ], unique: true
  end
end
