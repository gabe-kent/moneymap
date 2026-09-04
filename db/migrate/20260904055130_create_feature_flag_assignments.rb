class CreateFeatureFlagAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_flag_assignments do |t|
      t.references :feature_flag, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :feature_flag_assignments, [ :feature_flag_id, :user_id ], unique: true,
      name: "index_feature_flag_assignments_on_flag_and_user"
  end
end
