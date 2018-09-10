class CreateJobRuns < ActiveRecord::Migration[5.2]
  def change
    create_table :job_runs do |t|
      t.string :output_location
      t.integer :job_type
      t.references :bundle_context, foreign_key: true, null: false
      t.timestamps
    end
  end
end
