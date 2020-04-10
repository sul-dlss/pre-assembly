json.array! @job_runs do |job_run|
  json.merge! job_run.attributes
  json.sunet_id job_run.batch_context.user.sunet_id
end
