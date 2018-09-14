RSpec.describe JobRun, type: :model do
  let(:user) { User.new(sunet_id: 'Jdoe') }
  let(:bc) do
    BundleContext.new(project_name: 'SmokeTest',
                      content_structure: 1,
                      bundle_dir: 'spec/test_data/bundle_input_g',
                      staging_style_symlink: false,
                      content_metadata_creation: 1,
                      user: user)
  end
  let(:discovery_report_run) do
    described_class.new(output_location: '/path/to/report', bundle_context: bc, job_type: 'discovery_report')
  end

  it { is_expected.to belong_to(:bundle_context) }

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
      expect(described_class.new(bundle_context: bc)).not_to be_valid
      expect(discovery_report_run).to be_valid
    end
  end
end
