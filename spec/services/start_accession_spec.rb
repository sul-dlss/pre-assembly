# frozen_string_literal: true

RSpec.describe StartAccession do
  describe '.run' do
    subject(:start_accession) { described_class.run(druid:, batch_context:, workflow: 'assemblyWF') }

    let(:user) { create(:user) }
    let(:druid) { 'druid:gn330dv6119' }
    let(:accession_object) { instance_double(Dor::Services::Client::Accession, start: true) }
    let(:object_client) { instance_double(Dor::Services::Client::Object, accession: accession_object) }
    let(:batch_context) { instance_double(BatchContext, user:, run_ocr:, run_stt:, manually_corrected_ocr:, ocr_languages:) }

    before do
      allow(Dor::Services::Client).to receive(:object).and_return(object_client)
    end

    context 'when api client is successful' do
      context 'when we do not need to set workflow context' do
        let(:run_ocr) { false }
        let(:run_stt) { false }
        let(:manually_corrected_ocr) { false }
        let(:ocr_languages) { [] }

        it 'starts accession and leaves off workflow context' do
          start_accession
          expect(object_client.accession).to have_received(:start).with(
            description: 'pre-assembly re-accession',
            opening_user_name: user.sunet_id,
            workflow: 'assemblyWF'
          )
        end
      end

      context 'when we need to set workflow context for running OCR' do
        let(:run_ocr) { true }
        let(:run_stt) { false }
        let(:manually_corrected_ocr) { false }
        let(:ocr_languages) { %w[English Spanish] }

        it 'starts accession and adds workflow context' do
          start_accession
          expect(object_client.accession).to have_received(:start).with(
            description: 'pre-assembly re-accession',
            opening_user_name: user.sunet_id,
            workflow: 'assemblyWF',
            context: { runOCR: true, ocrLanguages: %w[English Spanish] }
          )
        end
      end

      context 'when we need to set workflow context for manually run OCR' do
        let(:run_ocr) { false }
        let(:run_stt) { false }
        let(:manually_corrected_ocr) { true }
        let(:ocr_languages) { [] }

        it 'starts accession and adds workflow context' do
          start_accession
          expect(object_client.accession).to have_received(:start).with(
            description: 'pre-assembly re-accession',
            opening_user_name: user.sunet_id,
            workflow: 'assemblyWF',
            context: { manuallyCorrectedOCR: true }
          )
        end
      end

      context 'when we need to set workflow context for running speech to text' do
        let(:run_ocr) { false }
        let(:run_stt) { true }
        let(:manually_corrected_ocr) { false }
        let(:ocr_languages) { [] }

        it 'starts accession and adds workflow context' do
          start_accession
          expect(object_client.accession).to have_received(:start).with(
            description: 'pre-assembly re-accession',
            opening_user_name: user.sunet_id,
            workflow: 'assemblyWF',
            context: { runSpeechToText: true }
          )
        end
      end
    end

    context 'when the api client raises' do
      let(:run_ocr) { false }
      let(:run_stt) { false }
      let(:manually_corrected_ocr) { false }
      let(:ocr_languages) { [] }

      before do
        allow(object_client).to receive(:accession).and_raise(StandardError)
      end

      it 'raises an exception' do
        expect { start_accession }.to raise_error(StandardError)
      end
    end
  end
end
