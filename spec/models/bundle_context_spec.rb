RSpec.describe BundleContext, type: :model do
  subject(:bc) do
    BundleContext.new(
      project_name: "SmokeTest",
      content_structure: 1,
      bundle_dir: "spec/test_data/bundle_input_g/",
      staging_style_symlink: false,
      content_metadata_creation: 1,
      user: user
    )
  end

  let(:user) { User.new(sunet_id: "Jdoe") }

  context "validation" do
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

    context "bundle_dir path does not exist" do
      it "object does not pass validation" do
        expect { bc.bundle_dir = 'does/not/exist' }.to change { bc.valid? }.to(false) 
      end
    end

    it { is_expected.to validate_presence_of(:project_name) }
    it { is_expected.to validate_presence_of(:content_structure) }
    it { is_expected.to validate_presence_of(:bundle_dir) }
    it { is_expected.to validate_presence_of(:content_metadata_creation) }
    it { is_expected.to belong_to(:user) }
  end

  describe "#staging_dir" do
    it 'is hardcoded to the correct path' do
      expect(described_class.new.staging_dir).to eq '/dor/assembly'
    end
  end

  describe "#normalize_bundle_dir" do
    it "removes the trailing forward slash" do
      expect(bc.normalize_bundle_dir).to eq "spec/test_data/bundle_input_g"
    end
  end

  describe "#content_tag_override?" do
    it "is set to true" do
      expect(described_class.new.content_tag_override?).to be true
    end
  end

  describe "#smpl_manifest" do
    it "returns the file name" do
      expect(described_class.new.smpl_manifest).to eq 'smpl_manifest.csv'
    end
  end

  describe "#manifest" do
    it "returns the file name" do
      expect(described_class.new.manifest).to eq 'manifest.csv'
    end
  end

  describe "#path_in_bundle" do
    it "creates a relative path" do
      expect(bc.path_in_bundle("manifest.csv")).to eq "spec/test_data/bundle_input_g/manifest.csv"
    end
  end

  describe "#progress_log_file" do
    skip("Need to figure out where to set this path via planning meeting 9/10/18")
  end

  describe '#import_csv' do
    let(:manifest) do
      described_class.import_csv("#{Rails.root}/spec/test_data/bundle_input_a/manifest.csv")
    end

    it "loads a CSV as a hash with indifferent access" do
      expect(manifest).to be_an(Array)
      expect(manifest.size).to eq(3)
      headers = %w{format sourceid filename label year inst_notes prod_notes has_more_metadata description}
      expect(manifest).to all(be_an(ActiveSupport::HashWithIndifferentAccess)) # accessible w/ string and symbols
      expect(manifest).to all(include(*headers))
      expect(manifest[0][:description]).to be_nil
      expect(manifest[1][:description]).to eq('')
      expect(manifest[2][:description]).to eq('yo, this is a description')
    end
  end

  describe "manifest_rows" do
    it "loads the manifest CSV" do
      expect(described_class).to receive(:import_csv).with("spec/test_data/bundle_input_g/manifest.csv")
      bc.manifest_rows
    end

    it "memoizes the manifest rows" do
      expect(described_class).to receive(:import_csv).once.with("spec/test_data/bundle_input_g/manifest.csv").and_call_original
      2.times { bc.manifest_rows }
    end

    it "expect the content of manifest rows" do
      expect(bc.manifest_rows).to eq(
        [
          {"druid"=>"druid:jy812bp9403", "sourceid"=>"bar-1.0", "folder"=>"jy812bp9403", "label"=>"Label 1", "description"=>"This is a description for label 1"},
          {"druid"=>"druid:tz250tk7584", "sourceid"=>"bar-2.1", "folder"=>"tz250tk7584", "label"=>"Label 2", "description"=>"This is a description for label 2"},
          {"druid"=>"druid:gn330dv6119", "sourceid"=>"bar-3.1", "folder"=>"gn330dv6119", "label"=>"Label 3", "description"=>"This is a description for label 3"}
        ]
      )
    end
  end

  describe "manifest_cols" do
    it "sets the column names" do
      expect(bc.manifest_cols).to eq(
        label: 'label',
        source_id: 'sourceid',
        object_container: 'object', # object referring to filename or foldername
        druid: 'druid'
      )
    end
  end
end
