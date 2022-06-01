class AddJobStatus < ActiveRecord::Migration[7.0]
  def change
    add_column :job_runs, :state, :string, null: false, default: 'waiting'
    add_index :job_runs, :state
  end
end
