class ErrorMessage < ActiveRecord::Migration[7.0]
  def change
    add_column :job_runs, :error_message, :text, null: true
  end
end
