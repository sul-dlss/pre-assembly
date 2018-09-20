json.array! @job_runs do |job_run|
  json.merge! job_run.attributes
  json.sunet_id job_run.bundle_context.user.sunet_id
end
