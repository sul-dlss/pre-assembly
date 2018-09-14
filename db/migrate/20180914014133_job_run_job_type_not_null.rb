class JobRunJobTypeNotNull < ActiveRecord::Migration[5.2]
  def change
    change_column_null :job_runs, :job_type, false
  end
end
