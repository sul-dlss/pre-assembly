# frozen_string_literal: true

RSpec.describe JobMailer do
  RSpec::Matchers.define_negated_matcher :not_include, :include

  let(:job_run) { create(:job_run, :discovery_report) }
  let(:job_notification) { described_class.with(job_run:).completion_email }
  let(:actual_file) { Rails.root.join('spec/fixtures/input/mock_progress_log.yaml') } # an existing file we can use for tests
  let(:completed_accession) { create(:accession, :completed, job_run:) }
  let(:failed_accession) { create(:accession, :failed, job_run:) }

  before do
    allow(job_run).to receive_messages(progress_log_file: actual_file, progress_log_file_exists?: true)
  end

  it 'renders the headers' do
    expect(job_notification.subject).to eq('[Test_Project] Your Discovery report job completed')
    expect(job_notification.to).to eq([job_run.batch_context.user.email])
    expect(job_notification.from).to eq(['no-reply-preassembly-job@stanford.edu'])
  end

  describe 'subject' do
    before { job_run.job_type = 1 } # switch job type to verify the subject line changes

    it 'adapts depending on job_type' do
      expect(job_notification.subject).to eq('[Test_Project] Your Preassembly job completed')
    end
  end

  describe 'body' do
    context 'for a discovery report email' do
      before { job_run.state = 'discovery_report_complete' }

      it 'renders the body' do
        expect(job_notification.body.encoded).to include("Your Discovery report job ##{job_run.id} finished with status 'Discovery report completed'")
          .and include("http://localhost:3000/job_runs/#{job_run.id}")
      end
    end

    context 'for a preassembly job report email' do
      before do
        job_run.job_type = 1
        job_run.state = 'preassembly_complete'
        job_run.accessions = accessions
      end

      context 'when there are complete and failed accessions' do
        let(:accessions) { [completed_accession, failed_accession] }

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
end
