class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.string :description
      t.date :occurred_on, null: false
      t.string :txn_type, null: false

      t.timestamps
    end

    add_index :transactions, [ :user_id, :occurred_on ]
  end
end
