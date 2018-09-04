require 'dor-services'

Dor::Config.dor_services.url ||= Dor::Config.dor.service_root

# TODO: use dor-workflow-service gem (see #194)
# require 'dor-workflow-service'
# Dor::WorkflowService.configure(
#   Settings.workflow_services_url,
#   :dor_services_url => Dor::Config.dor_services.url.gsub('/v1', '')
# )
