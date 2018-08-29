require 'dor-services'
require 'dor-workflow-service'

Dor::Config.dor_services.url ||= Dor::Config.dor.service_root
Dor::WorkflowService.configure(
  Settings.workflow_services_url,
  :dor_services_url => Dor::Config.dor_services.url.gsub('/v1', '')
)

