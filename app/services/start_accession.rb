# frozen_string_literal: true

# Starts the accession workflow by calling dor-services-app
# See https://sul-dlss.github.io/dor-services-app/#operation/objects#accession
class StartAccession
  def self.run(druid:, batch_context:, workflow: nil)
    object_client = Dor::Services::Client.object(druid)

    workflow_context = {}
    workflow_context[:runOCR] = batch_context.run_ocr
    workflow_context[:manuallyCorrectedOCR] = batch_context.manually_corrected_ocr
    workflow_context[:ocrLanguages] = batch_context.ocr_languages unless batch_context.ocr_languages.empty?

    params = { description: 'pre-assembly re-accession', opening_user_name: batch_context.user.sunet_id, workflow: }
    params[:context] = workflow_context if workflow_context.present?

    object_client.accession.start(params)
  end
end
