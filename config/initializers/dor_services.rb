require 'dor-services'

Dor::Config.configure do
  ssl do
    cert_file Settings.dor_client_cert
    key_file Settings.dor_client_cert_key
  end

  # used to make dor-workflow-service call for a druid
  #   this is done at end of preassembly to kick off assembly
  # TODO: use dor-workflow-service gem instead (see #194)
  dor_services do
    url Settings.DOR_SERVICES.URL
    user Settings.DOR_SERVICES.USER
    pass Settings.DOR_SERVICES.PASS
    num_attempts Settings.dor_services_num_attempts
  end

  # used to look up object existence in DOR for discovery report
  fedora do
    # used to look up objects in DOR
    url Settings.fedora_url
  end
end

# TODO: use dor-workflow-service gem (see #194) instead of dor_services gem
# require 'dor-workflow-service'
# Dor::WorkflowService.configure(
#   Settings.workflow_services_url,
#   dor_services_url: Dor::Config.dor_services.url.gsub('/v1', '')
# )
