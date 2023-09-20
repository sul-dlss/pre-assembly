class CreateGlobusDestinations < ActiveRecord::Migration[7.0]
  def change
    create_table :globus_destinations do |t|
      t.timestamp :deleted_at
      t.references :batch_context, foreign_key: true, null: true
      t.references :user, foreign_key: true, null: false
      t.timestamps
    end
  end
end
