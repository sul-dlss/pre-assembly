RSpec.describe BundleContext, type: :model do
  subject(:bc) { build(:bundle_context_with_deleted_output_dir, attr_hash) }

  let(:attr_hash) do
    {
      project_name: 'Images_jp2_tif',
      bundle_dir: 'spec/test_data/images_jp2_tif'
    }
  end

  context 'validation' do
    it 'is not valid unless it has all required attributes' do
      expect(BundleContext.new).not_to be_valid
      expect(bc).to be_valid
    end
    it 'is not valid without a User' do
      expect { bc.user = nil }.to change(bc, :valid?).to(false)
    end
    it 'is not valid unless bundle_dir exists on filesystem' do
      expect { bc.bundle_dir = 'does/not/exist' }.to change(bc, :valid?).to(false)
    end
    it { is_expected.to validate_presence_of(:content_structure) }
    it { is_expected.to validate_presence_of(:bundle_dir) }
    it { is_expected.to validate_presence_of(:content_metadata_creation) }
    it { is_expected.to validate_presence_of(:project_name) }

    describe 'project_name' do
      it 'is not valid with chars other than alphanum, hyphen and underscore' do
        expect { bc.project_name = 's p a c e s' }.to change(bc, :valid?).to(false)
        bc.project_name = "apostrophe's"
        expect(bc.valid?).to eq false
        bc.project_name = 'quotes"'
        expect(bc.valid?).to eq false
      end
      it 'is valid with alphanum, hyphen and underscore chars' do
        valid_chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'
        expect { bc.project_name = valid_chars }.not_to change(bc, :valid?).from(true)
      end
    end

    context 'bundle_dir must be a sub dir of allowed parent directories' do
      it 'cannot jailbreak' do
        expect { bc.bundle_dir = 'tmp/../../foo/' }.to change(bc, :valid?).to(false)
      end

      it 'cannot use the root directly' do
        expect { bc.bundle_dir = 'tmp/' }.to change(bc, :valid?).to(false)
      end
    end
  end

  it do
    is_expected.to define_enum_for(:content_structure).with(
      'simple_image' => 0,
      'simple_book' => 1,
      'book_as_image' => 2,
      'file' => 3,
      'smpl' => 4
    )
  end
  it do
    is_expected.to define_enum_for(:content_metadata_creation).with(
      'default' => 0,
      'filename' => 1,
      'smpl_cm_style' => 2
    )
  end

  it { is_expected.to belong_to(:user) }

  it 'enums default to their default values' do
    bc = described_class.new
    expect(bc.content_structure).to eq 'simple_image'
    expect(bc.content_metadata_creation).to eq 'default'
  end

  it 'bundle_dir has trailing slash removed' do
    expect(bc.bundle_dir).to eq 'spec/test_data/images_jp2_tif'
  end

  describe '#bundle' do
    it 'returns a PreAssembly::Bundle' do
      expect(bc.bundle).to be_a(PreAssembly::Bundle)
    end
    it 'caches the Bundle' do
      expect(bc.bundle).to be(bc.bundle) # same instance
    end
  end

  describe '#assembly_staging_dir' do
    it 'comes from Settings file' do
      expect(described_class.new.assembly_staging_dir).to eq Settings.assembly_staging_dir
    end
  end

  describe '#smpl_manifest' do
    it 'returns the file name' do
      expect(described_class.new.smpl_manifest).to eq 'smpl_manifest.csv'
    end
  end

  describe '#manifest' do
    it 'returns the file name' do
      expect(described_class.new.manifest).to eq 'manifest.csv'
    end
  end

  describe '#path_in_bundle' do
    it 'creates a relative path' do
      expect(bc.path_in_bundle('manifest.csv')).to eq 'spec/test_data/images_jp2_tif/manifest.csv'
    end
  end

  describe 'output_dir' do
    it 'returns "Settings.job_output_parent_dir/user_id/project_name"' do
      expect(bc.output_dir).to eq "#{Settings.job_output_parent_dir}/#{bc.user.email}/#{bc.project_name}"
    end
  end

  describe '#progress_log_file' do
    it 'is project_name + "_progress.yml" in output_dir' do
      expect(bc.progress_log_file).to eq "#{bc.output_dir}/#{bc.project_name}_progress.yml"
    end
  end

  describe 'manifest_rows' do
    it 'loads the manifest CSV' do
      expect(CsvImporter).to receive(:parse_to_hash).with('spec/test_data/images_jp2_tif/manifest.csv')
      bc.manifest_rows
    end

    it 'memoizes the manifest rows' do
      expect(CsvImporter).to receive(:parse_to_hash).once.with('spec/test_data/images_jp2_tif/manifest.csv').and_call_original
      2.times { bc.manifest_rows }
    end

    it 'expect the content of manifest rows' do
      expect(bc.manifest_rows).to eq(
        [
          { 'druid' => 'druid:jy812bp9403', 'sourceid' => 'bar-1.0', 'object' => 'jy812bp9403', 'label' => 'Label 1', 'description' => 'This is a description for label 1' },
          { 'druid' => 'druid:tz250tk7584', 'sourceid' => 'bar-2.1', 'object' => 'tz250tk7584', 'label' => 'Label 2', 'description' => 'This is a description for label 2' },
          { 'druid' => 'druid:gn330dv6119', 'sourceid' => 'bar-3.1', 'object' => 'gn330dv6119', 'label' => 'Label 3', 'description' => 'This is a description for label 3' }
        ]
      )
    end
  end

  describe '#output_dir_no_exists!' do
    before { FileUtils.mkdir_p(Settings.job_output_parent_dir) }

    after { Dir.delete(bc.output_dir) if Dir.exist?(bc.output_dir) } # cleanup

    context 'when bundle_context is new' do
      before { allow(bc).to receive(:persisted?).and_return(false) }

      it 'creates directory' do
        expect { bc.send(:output_dir_no_exists!) }.to change { Dir.exist?(bc.output_dir) }.from(false).to(true)
      end
      it 'adds error if directory already exists' do
        FileUtils.mkdir_p(bc.output_dir) unless Dir.exist?(bc.output_dir)
        expect(bc).to receive(:throw)
        bc.send(:output_dir_no_exists!)
        expect(bc.errors).not_to be_empty
      end
      it "adds error if directory can't be created" do
        allow(bc).to receive(:output_dir).and_return('/bootx/foo')
        expect { bc.send(:output_dir_no_exists!) }.to raise_error(SystemCallError, /Permission denied @ dir_s_mkdir - \/bootx/)
      end
    end
  end

  describe '#output_dir_exists!' do
    context 'when bundle_context is not new' do
      before { allow(bc).to receive(:persisted?).and_return(true) } # fake save

      it "adds error if directory doesn't exist" do
        expect(bc).to receive(:throw)
        bc.send(:output_dir_exists!)
        expect(bc.errors).not_to be_empty
      end
    end
  end

  describe '#verify_bundle_directory' do
    it 'does nothing if bundle_dir already has errors' do
      bc.errors.add(:bundle_dir, 'test')
      expect(File).not_to receive(:directory?)
      expect { bc.send(:verify_bundle_directory) }.not_to change(bc, :errors)
    end
    it 'adds error if missing manifest.csv' do
      allow(File).to receive(:exist?).with('spec/test_data/images_jp2_tif/manifest.csv').and_return(false)
      bc.send(:verify_bundle_directory)
      expect(bc.errors.to_h).to include(bundle_dir: /missing manifest/)
    end
    it 'adds error if spml object is missing smpl_manifest.csv' do
      allow(bc).to receive(:smpl_cm_style?).and_return(true)
      bc.send(:verify_bundle_directory)
      expect(bc.errors.to_h).to include(bundle_dir: /missing SMPL manifest/)
    end
  end
end
