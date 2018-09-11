RSpec.describe BundleContext, type: :model do
  subject(:bc) do
    BundleContext.new(
      project_name: "Images jp2 tif",
      content_structure: 1,
      bundle_dir: "spec/test_data/images_jp2_tif/",
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
          "simple_image" => 0,
          "simple_book" => 1,
          "book_as_image" => 2,
          "file" => 3,
          "smpl" => 4
        )
      end

      it "content_metadata_creation enum" do
        is_expected.to define_enum_for(:content_metadata_creation).with(
          "default" => 0,
          "filename" => 1,
          "smpl_cm_style" => 2
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
        expect(described_class.new(content_structure: :smpl).content_structure).to eq 'smpl'
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
        expect(described_class.new(content_metadata_creation: :smpl_cm_style).content_metadata_creation).to eq 'smpl_cm_style'
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
      expect(described_class.new.staging_dir).to eq '/tmp/assembly'
    end
  end

  describe "#normalize_bundle_dir" do
    it "removes the trailing forward slash" do
      expect(bc.normalize_bundle_dir).to eq "spec/test_data/images_jp2_tif"
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
      expect(bc.path_in_bundle("manifest.csv")).to eq "spec/test_data/images_jp2_tif/manifest.csv"
    end
  end

  describe "#progress_log_file" do
    skip("Need to figure out where to set this path via planning meeting 9/10/18")
  end

  describe "manifest_rows" do
    it "loads the manifest CSV" do
      expect(CsvImporter).to receive(:parse_to_hash).with("spec/test_data/images_jp2_tif/manifest.csv")
      bc.manifest_rows
    end

    it "memoizes the manifest rows" do
      expect(CsvImporter).to receive(:parse_to_hash).once.with("spec/test_data/images_jp2_tif/manifest.csv").and_call_original
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
