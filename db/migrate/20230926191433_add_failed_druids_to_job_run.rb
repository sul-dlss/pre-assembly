class AddFailedDruidsToJobRun < ActiveRecord::Migration[7.0]
  def change
    add_column :job_runs, :objects_with_error, :jsonb, null: false, default: []
  end
end
