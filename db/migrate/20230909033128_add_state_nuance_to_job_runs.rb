class AddStateNuanceToJobRuns < ActiveRecord::Migration[7.0]
  # JobRun#job_type enum: 'discovery_report' is 0, 'preassembly' is 1
  def up
    execute <<-SQL
      UPDATE job_runs
      SET state = (CASE job_type WHEN 0 THEN 'discovery_report_complete_with_errors'
                                 WHEN 1 THEN 'preassembly_complete_with_errors'
                                 ELSE state
                   END)
      WHERE state = 'complete_with_errors';

      UPDATE job_runs
      SET state = (CASE job_type WHEN 0 THEN 'discovery_report_complete'
                                 WHEN 1 THEN 'preassembly_complete'
                                 ELSE state
                   END)
      WHERE state = 'complete';
    SQL
  end

  def down
    execute <<-SQL
      UPDATE job_runs
      SET state = 'complete_with_errors'
      WHERE state in ('discovery_report_complete_with_errors', 'preassembly_complete_with_errors');

      UPDATE job_runs
      SET state = 'complete'
      WHERE state in ('discovery_report_complete', 'preassembly_complete');
    SQL
  end
end
