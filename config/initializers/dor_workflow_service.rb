require 'dor-workflow-service'
Dor::WorkflowService.configure(
  Settings.workflow_services_url,
  :dor_services_url => Dor::Config.dor_services.url.gsub('/v1', '')
)
