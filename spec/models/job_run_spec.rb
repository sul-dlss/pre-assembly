require 'rails_helper'

RSpec.describe JobRun, type: :model do
  context "validation" do
    let(:user) do
      User.new(sunet_id: "Jdoe")
    end

    let(:bc) do
      BundleContext.new(project_name: "SmokeTest",
                        content_structure: 1,
                        bundle_dir: "spec/test_data/images_jp2_tif",
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
          "pre_assembly" => 1
        )
      end
    end

    it { is_expected.to belong_to(:bundle_context) }
  end
end
