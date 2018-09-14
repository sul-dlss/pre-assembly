require 'rails_helper'

RSpec.describe JobRun, type: :model do

  context "validation" do
    let(:user) do
      User.new(sunet_id: "Jdoe")
    end

    let(:bc) do
      BundleContext.new(project_name: "SmokeTest",
                        content_structure: 1,
                        bundle_dir: "spec/test_data/bundle_input_g",
                        staging_style_symlink: false,
                        content_metadata_creation: 1,
                        user: user)
    end

    let(:discovery_report_run) do
      JobRun.new(output_location: "/path/to/report",
                 bundle_context: bc,
                 job_type: "discovery_report")
    end

    it "is not valid if it doesn't have the required fields" do
      expect(JobRun.new).not_to be_valid
      expect(discovery_report_run).to be_valid
    end

    context "#job_type enum" do
      it "defines expected values" do
        is_expected.to define_enum_for(:job_type).with(
          "discovery_report" => 0,
          "preassembly" => 1
        )
      end
    end

    it { is_expected.to belong_to(:bundle_context) }

    context 'job_type' do
      it 'valid values' do
        expect(JobRun.new(job_type: 0, bundle_context: bc)).to be_valid
        expect(JobRun.new(job_type: 1, bundle_context: bc)).to be_valid
        expect(JobRun.new(job_type: 'discovery_report', bundle_context: bc)).to be_valid
        expect(JobRun.new(job_type: 'preassembly', bundle_context: bc)).to be_valid
      end
      it 'throws ArgumentError if value missing from enum' do
        expect { JobRun.new(job_type: 3, bundle_context: bc) }.to raise_error(ArgumentError, /'3' is not a valid job_type/)
        expect { JobRun.new(job_type: 'foo', bundle_context: bc) }.to raise_error(ArgumentError, /'foo' is not a valid job_type/)
      end
      it 'is required' do
        expect(JobRun.new(bundle_context: bc)).not_to be_valid
      end
    end
  end

end
