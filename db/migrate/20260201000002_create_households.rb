class CreateHouseholds < ActiveRecord::Migration[6.1]
  def change
    create_table :households do |t|
      t.string :name, null: false
      t.string :external_id  # For linking to tools/myecfo/taxes
      t.timestamps
    end

    add_index :households, :external_id, unique: true
  end
end
