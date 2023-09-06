class CreateAccessions < ActiveRecord::Migration[7.0]
  def change
    create_table :accessions do |t|
      t.string :druid, null: false
      t.integer :version, null: false
      t.timestamp :completed_at
      t.references :job_run, foreign_key: true, null: false
      t.timestamps
    end
  end
end
