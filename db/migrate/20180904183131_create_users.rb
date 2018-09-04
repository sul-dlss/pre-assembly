class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.string :sunet_id, null: false, unique: true, index: true

      t.timestamps
    end
  end
end
