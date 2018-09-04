class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.string :sunet_id, null: false

      t.timestamps
    end
    add_index :users, :sunet_id, unique: true
  end
end
