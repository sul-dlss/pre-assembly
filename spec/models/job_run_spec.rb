RSpec.describe JobRun, type: :model do
  let(:bc) do
    BundleContext.new(
      project_name: 'ImagesJp2Tif',
      content_structure: 1,
      bundle_dir: 'spec/test_data/images_jp2_tif',
      staging_style_symlink: false,
      content_metadata_creation: 1,
      user: build(:user)
    ).tap do |bc|
      Dir.delete(bc.output_dir) if Dir.exist?(bc.output_dir)
      bc.save!
    end
  end
  let(:job_run) do
    described_class.new(output_location: '/path/to/report', bundle_context: bc, job_type: 'discovery_report')
  end

  it { is_expected.to belong_to(:bundle_context) }

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

  describe 'send_notification' do
    let(:mock_mailer) { double JobMailer }
    let(:mock_delivery) { double ActionMailer::MessageDelivery }
    before { job_run.save }
    it 'does not send an email if output_location is unchanged' do
      expect(job_run).not_to receive(:send_notification)
      job_run.save
    end
    it 'does not send a notification email if output_location is changed but is nil' do
      expect(job_run).to receive(:send_notification).and_call_original
      expect(JobMailer).not_to receive(:with)
      job_run.output_location = nil
      job_run.save
    end
    it 'sends a notification email if output_location is saved with a changed non-nil value' do
      expect(job_run).to receive(:send_notification).and_call_original
      expect(JobMailer).to receive(:with).with(job_run: job_run).and_return(mock_mailer)
      expect(mock_mailer).to receive(:completion_email).and_return(mock_delivery)
      expect(mock_delivery).to receive(:deliver_later)
      job_run.output_location += '/tmp'
      job_run.save
    end
  end

  describe '#job_type enum' do
    it 'defines expected values' do
      is_expected.to define_enum_for(:job_type).with(
        'discovery_report' => 0,
        'preassembly' => 1
      )
    end
  end

  context 'validation' do
    it 'is not valid without all required fields' do
      expect(described_class.new).not_to be_valid
      expect(described_class.new(bundle_context: bc)).not_to be_valid
      expect(job_run).to be_valid
    end
  end
end
