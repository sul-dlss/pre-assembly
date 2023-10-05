# frozen_string_literal: true

RSpec.describe JobRun do
  let(:job_run) { build(:job_run) }

  it { is_expected.to belong_to(:batch_context) }

  describe 'enqueue!' do
    it 'does nothing if unpersisted' do
      expect(DiscoveryReportJob).not_to receive(:perform_later)
      job_run.enqueue!
    end

    it 'calls the correct job for job_type' do
      allow(job_run).to receive(:persisted?).and_return(true)
      expect(DiscoveryReportJob).to receive(:perform_later).with(job_run)
      job_run.enqueue!
      job_run.job_type = 'preassembly'
      expect(PreassemblyJob).to receive(:perform_later).with(job_run)
      job_run.enqueue!
    end
  end

  describe 'send preassembly completed notification' do
    let(:mock_mailer) { instance_double JobMailer }
    let(:mock_delivery) { instance_double ActionMailer::MessageDelivery }

    before { job_run.started }

    it 'does not send an email when job is started' do
      expect(job_run).not_to receive(:send_preassembly_notification)
    end

    it 'sends a notification email when job_run completes' do
      expect(JobMailer).to receive(:with).with(job_run:).and_return(mock_mailer)
      expect(mock_mailer).to receive(:completion_email).and_return(mock_delivery)
      expect(mock_delivery).to receive(:deliver_now)
      job_run.completed
    end

    it 'sends a notification email when job_run fails' do
      expect(JobMailer).to receive(:with).with(job_run:).and_return(mock_mailer)
      expect(mock_mailer).to receive(:completion_email).and_return(mock_delivery)
      expect(mock_delivery).to receive(:deliver_now)
      job_run.failed
    end

    it 'sends a notification email when job_run completes with errors' do
      expect(JobMailer).to receive(:with).with(job_run:).and_return(mock_mailer)
      expect(mock_mailer).to receive(:completion_email).and_return(mock_delivery)
      expect(mock_delivery).to receive(:deliver_now)
      job_run.error_message = 'something went wrong'
      job_run.completed
    end
  end

  describe 'send accessioning completed notification' do
    let(:job_run) { build(:job_run, state: 'preassembly_complete') }
    let(:mock_mailer) { instance_double JobMailer }
    let(:mock_delivery) { instance_double ActionMailer::MessageDelivery }

    it 'sends a notification email when accessioning completes' do
      expect(JobMailer).to receive(:with).with(job_run:).and_return(mock_mailer)
      expect(mock_mailer).to receive(:accession_completion_email).and_return(mock_delivery)
      expect(mock_delivery).to receive(:deliver_now)
      job_run.accessioning_completed
    end
  end

  describe '#job_type enum' do
    it 'defines expected values' do
      is_expected.to define_enum_for(:job_type).with_values(
        'discovery_report' => 0,
        'preassembly' => 1
      )
    end

    it 'defaults to correct value' do
      expect(described_class.new.job_type).to eq('discovery_report')
    end
  end

  context 'validation' do
    it 'is not valid without all required fields' do
      expect(described_class.new).not_to be_valid
    end

    it 'is valid with just batch_context' do
      expect(described_class.new(batch_context: build(:batch_context))).to be_valid
    end
  end

  describe '#batch' do
    it 'returns a PreAssembly::Batch' do
      expect(job_run.batch).to be_a(PreAssembly::Batch)
    end

    # rubocop:disable RSpec/IdenticalEqualityAssertion
    it 'caches the Batch' do
      expect(job_run.batch).to be(job_run.batch) # same instance
    end
    # rubocop:enable RSpec/IdenticalEqualityAssertion
  end

  describe '#human_state_name' do
    let(:name) { job_run.human_state_name }
    let(:state) { 'waiting' }

    context 'when discovery report' do
      let(:job_run) { build(:job_run, :discovery_report, state: 'discovery_report_complete', error_message:) }
      let(:error_message) { nil }

      context 'when no errors' do
        it 'returns name' do
          expect(name).to eq('Discovery report completed')
        end
      end

      context 'when errors' do
        let(:error_message) { 'Drat' }

        it 'returns name' do
          expect(name).to eq('Discovery report completed (with errors)')
        end
      end
    end

    context 'when preassembly' do
      let(:job_run) { create(:job_run, :preassembly, state:, error_message:) }
      let(:error_message) { nil }

      context 'when accessioning complete' do
        let(:state) { 'accessioning_complete' }

        before do
          create(:accession, job_run:)
        end

        context 'when no errors' do
          it 'returns name' do
            expect(name).to eq('Job completed')
          end
        end

        context 'when preassembly errors' do
          let(:error_message) { 'Drat' }

          it 'returns name' do
            expect(name).to eq('Job completed (with preassembly errors)')
          end
        end

        context 'when accession errors' do
          before do
            create(:accession, state: 'failed', job_run:)
          end

          it 'returns name' do
            expect(name).to eq('Job completed (with accessioning errors)')
          end
        end

        context 'when preassembly and accession errors' do
          let(:error_message) { 'Drat' }

          before do
            create(:accession, state: 'failed', job_run:)
          end

          it 'returns name' do
            expect(name).to eq('Job completed (with preassembly and accessioning errors)')
          end
        end
      end

      context 'when preassembly complete' do
        let(:state) { 'preassembly_complete' }

        context 'when preassembly errors' do
          let(:error_message) { 'Drat' }

          it 'returns name' do
            expect(name).to eq('Job completed (with preassembly errors)')
          end
        end
      end
    end
  end
end
