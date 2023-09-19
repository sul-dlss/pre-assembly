class RenameBatchContext < ActiveRecord::Migration[7.0]
  def change
    rename_table :batch_contexts, :projects
    rename_column :job_runs, :batch_context_id, :project_id
  end
end
