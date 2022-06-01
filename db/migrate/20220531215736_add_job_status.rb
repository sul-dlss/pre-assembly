class AddJobStatus < ActiveRecord::Migration[7.0]
  def up
    add_column :job_runs, :state, :string, null: false, default: 'waiting'
    add_index :job_runs, :state
    # set all existing jobs with a finished output_location to completed
    JobRun.where.not(output_location: nil).find_each {|j| j.update_column(:state, 'complete')}
  end

  def down
    remove_column :job_runs, :state
  end
end
