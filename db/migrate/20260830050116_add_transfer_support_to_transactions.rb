class AddTransferSupportToTransactions < ActiveRecord::Migration[8.1]
  def change
    change_column_null :transactions, :category_id, true
    add_column :transactions, :transfer_id, :string
    safety_assured { add_index :transactions, :transfer_id }
  end
end
