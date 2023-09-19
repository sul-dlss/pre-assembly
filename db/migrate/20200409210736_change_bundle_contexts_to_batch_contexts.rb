class ChangeBundleContextsToProjects < ActiveRecord::Migration[6.0]
  def change
    rename_table :bundle_contexts, :batch_contexts
    change_table :job_runs do |t|
      t.rename :bundle_context_id, :batch_context_id
    end
  end
end
