RSpec.describe JobRun, type: :model do
  let(:user) { User.new(sunet_id: 'Jdoe@stanford.edu') }
  let(:bc) do
    BundleContext.new(project_name: 'SmokeTest',
                      content_structure: 1,
                      bundle_dir: 'spec/test_data/bundle_input_g',
                      staging_style_symlink: false,
                      content_metadata_creation: 1,
                      user: user)
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
