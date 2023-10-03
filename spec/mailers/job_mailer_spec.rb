# frozen_string_literal: true

RSpec.describe JobMailer do
  describe '.completion_email' do
    let(:job_notification) { described_class.with(job_run:).completion_email }

    context 'when a discovery report' do
      let(:job_run) { create(:job_run, :discovery_report, state: 'discovery_report_complete', objects_with_error: ['bbb111ccc1111']) }

      it 'renders the headers' do
        expect(job_notification.subject).to eq('[Test_Project] Your Discovery report job completed')
        expect(job_notification.to).to eq([job_run.batch_context.user.email])
        expect(job_notification.from).to eq(['no-reply-preassembly-job@stanford.edu'])
      end

      it 'renders the body' do
        expect(job_notification.body.encoded).to match(/Your Discovery report job #\d+ finished/)
          .and include('The following 1 object in your')
          .and include("http://localhost:3000/job_runs/#{job_run.id}")
          .and include('sdr-contact@lists.stanford.edu')
      end
    end

    context 'when a preassembly' do
      let(:job_run) { create(:job_run, :preassembly, state: 'preassembly_complete') }

      it 'renders the headers' do
        expect(job_notification.subject).to eq('[Test_Project] Your Preassembly job encountered an error')
      end
    end
  end

  describe '.accession_completion_email' do
    let(:job_notification) { described_class.with(job_run:).accession_completion_email }

    let(:job_run) { create(:job_run, :preassembly, state: 'accessioning_complete') }
    let(:accessions) { [completed_accession, failed_accession] }
    let(:completed_accession) { create(:accession, :completed, job_run:) }
    let(:failed_accession) { create(:accession, :failed, job_run:) }

    before do
      job_run.accessions = accessions
    end

    it 'renders the headers' do
      expect(job_notification.subject).to eq('[Test_Project] Job completed')
      expect(job_notification.to).to eq([job_run.batch_context.user.email])
      expect(job_notification.from).to eq(['no-reply-preassembly-job@stanford.edu'])
    end

    context 'when there are complete and failed accessions' do
      it 'renders the body' do
        expect(job_notification.body.encoded).to include("Your Preassembly job ##{job_run.id} has successfully accessioned the following SDR objects")
          .and include("http://localhost:3000/job_runs/#{job_run.id}")
          .and include('The following SDR items failed accessioning')
      end
    end

    context 'when there are only complete accessions' do
      let(:accessions) { [completed_accession] }

      it 'renders the body' do
        expect(job_notification.body.encoded).to include("Your Preassembly job ##{job_run.id} has successfully accessioned the following SDR objects")
          .and include("http://localhost:3000/job_runs/#{job_run.id}")
          .and not_include('The following SDR items failed accessioning')
      end
    end

    context 'when there are only failed accessions' do
      let(:accessions) { [failed_accession] }

      it 'renders the body' do
        expect(job_notification.body.encoded).to not_include("Your Preassembly job ##{job_run.id} has successfully accessioned the following SDR objects")
          .and include('The following SDR items failed accessioning')
      end
    end
  end
end
