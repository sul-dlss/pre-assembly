class UpdateJobRunState < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      UPDATE job_runs
      SET state = 'discovery_report_complete'
      WHERE state = 'discovery_report_complete_with_errors';

      UPDATE job_runs
      SET state = 'preassembly_complete'
      WHERE state = 'preassembly_complete_with_errors';
    SQL
  end

  def down
    execute <<-SQL
      UPDATE job_runs
      SET state = 'discovery_report_complete_with_errors'
      WHERE state = 'discovery_report_complete' AND error_message IS NOT NULL;

      UPDATE job_runs
      SET state = 'preassembly_complete_with_errors'
      WHERE state = preassembly_complete' AND error_message IS NOT NULL;
    SQL
  end
end
