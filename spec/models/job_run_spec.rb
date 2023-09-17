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

  describe 'send_error_notification' do
    let(:mock_mailer) { instance_double JobMailer }
    let(:mock_delivery) { instance_double ActionMailer::MessageDelivery }

    before { job_run.started }

    it 'does not send an email when job is started' do
      expect(job_run).not_to receive(:send_error_notification)
    end

    it 'guards against sending a notification email when the job is not done yet' do
      job_run.state = 'running'
      job_run.send_error_notification
      expect(JobMailer).not_to receive(:with)
    end

    it 'does not send a notification email when job_run completes' do
      expect(job_run).not_to receive(:send_error_notification)
      job_run.completed
    end

    it 'sends a notification email when job_run fails' do
      expect(JobMailer).to receive(:with).with(job_run:).and_return(mock_mailer)
      expect(mock_mailer).to receive(:completion_error_email).and_return(mock_delivery)
      expect(mock_delivery).to receive(:deliver_later)
      job_run.failed
    end

    it 'sends a notification email when job_run completes with errors' do
      expect(JobMailer).to receive(:with).with(job_run:).and_return(mock_mailer)
      expect(mock_mailer).to receive(:completion_error_email).and_return(mock_delivery)
      expect(mock_delivery).to receive(:deliver_later)
      job_run.completed_with_errors
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
end
