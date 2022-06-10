# frozen_string_literal: true

RSpec.describe BatchContext, type: :model do
  subject(:bc) { build(:batch_context_with_deleted_output_dir, attr_hash) }

  let(:attr_hash) do
    {
      project_name: 'Images_jp2_tif',
      bundle_dir: 'spec/test_data/images_jp2_tif'
    }
  end

  context 'validation' do
    it 'is not valid unless it has all required attributes' do
      expect(described_class.new).not_to be_valid
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
        expect(bc.valid?).to be false
        bc.project_name = 'quotes"'
        expect(bc.valid?).to be false
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
    is_expected.to define_enum_for(:content_structure).with_values(
      'simple_image' => 0,
      'simple_book' => 1,
      'book_as_image' => 2,
      'file' => 3,
      'media' => 4,
      '3d' => 5,
      'document' => 6,
      'maps' => 7,
      'webarchive_seed' => 8,
      'simple_book_rtl' => 9
    )
  end

  it do
    is_expected.to define_enum_for(:content_metadata_creation).with_values(
      'default' => 0,
      'filename' => 1,
      'media_cm_style' => 2
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

  describe '#batch' do
    it 'returns a PreAssembly::Batch' do
      expect(bc.batch).to be_a(PreAssembly::Batch)
    end

    # rubocop:disable RSpec/IdenticalEqualityAssertion
    it 'caches the Batch' do
      expect(bc.batch).to be(bc.batch) # same instance
    end
    # rubocop:enable RSpec/IdenticalEqualityAssertion
  end

  describe '#file_manifest' do
    it 'returns the file name' do
      expect(described_class.new.file_manifest).to eq 'file_manifest.csv'
    end
  end

  describe '#manifest' do
    it 'returns the file name' do
      expect(described_class.new.manifest).to eq 'manifest.csv'
    end
  end

  describe '#bundle_dir_with_path' do
    it 'creates a relative path' do
      expect(bc.bundle_dir_with_path('manifest.csv')).to eq 'spec/test_data/images_jp2_tif/manifest.csv'
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

    after { FileUtils.remove_dir(bc.output_dir) if Dir.exist?(bc.output_dir) } # cleanup

    context 'when batch_context is new' do
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
        expect { bc.send(:output_dir_no_exists!) }.to raise_error(SystemCallError, / @ dir_s_mkdir - \/bootx/)
      end
    end
  end

  describe '#output_dir_exists!' do
    context 'when batch_context is not new' do
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
      expect(bc.errors.map(&:type)).to include('missing manifest: spec/test_data/images_jp2_tif/manifest.csv')
    end

    it 'adds error if object selected for use with file manifest is missing file_manifest.csv' do
      allow(bc).to receive(:using_file_manifest).and_return(true)
      bc.send(:verify_bundle_directory)
      expect(bc.errors.map(&:type)).to include('missing file manifest: spec/test_data/images_jp2_tif/file_manifest.csv')
    end
  end
end
