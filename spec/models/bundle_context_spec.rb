require 'rails_helper'

RSpec.describe BundleContext, type: :model do
  context "validation" do
    let(:user) { User.new(sunet_id: "Jdoe")}
    subject(:bc) { BundleContext.new(project_name: "SmokeTest",
                                     content_structure: 1,
                                     bundle_dir: "spec/test_data/bundle_input_g",
                                     staging_style_symlink: false,
                                     content_metadata_creation: 1,
                                     user: user) }

    it "is not valid unless it has all required attributes" do
      expect(BundleContext.new).not_to be_valid
      expect(bc).to be_valid
    end

    context "defines enum with expected values" do
      it "content_structure enum" do
        is_expected.to define_enum_for(:content_structure).with(
          "simple_image_structure" => 0,
          "simple_book_structure" => 1,
          "book_as_iamge_structure" => 2,
          "file_structure" => 3,
          "smpl_structure" => 4
        )
      end

      it "content_metadata_creation enum" do
        is_expected.to define_enum_for(:content_metadata_creation).with(
          "default_style" => 0,
          "filename_style" => 1,
          "smpl_style" => 2
        )
      end
    end

    describe "#content_structure=" do
      it "validation rejects a value if it does not match the enum" do
        expect { described_class.new(content_structure: 654) }
          .to raise_error(ArgumentError, "'654' is not a valid content_structure")
        expect { described_class.new(content_structure: 'book_as_pdf') }
          .to raise_error(ArgumentError, "'book_as_pdf' is not a valid content_structure")
      end

      it "will accept a symbol, but will always return a string" do
        expect(described_class.new(content_structure: :smpl_structure).content_structure).to eq 'smpl_structure'
      end
    end

    describe "#content_metadata_creation=" do
      it "validation rejects a value if it does not match the enum" do
        expect { described_class.new(content_metadata_creation: 654) }
          .to raise_error(ArgumentError, "'654' is not a valid content_metadata_creation")
        expect { described_class.new(content_metadata_creation: 'dpg') }
          .to raise_error(ArgumentError, "'dpg' is not a valid content_metadata_creation")
      end

      it "will accept a symbol, but will always return a string" do
        expect(described_class.new(content_metadata_creation: :smpl_style).content_metadata_creation).to eq 'smpl_style'
      end
    end

    it { is_expected.to validate_presence_of(:project_name) }
    it { is_expected.to validate_presence_of(:content_structure) }
    it { is_expected.to validate_presence_of(:bundle_dir) }
    it { is_expected.to validate_presence_of(:content_metadata_creation) }
    it { is_expected.to belong_to(:user) }
  end
end
