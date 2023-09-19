# frozen_string_literal: true

RSpec.describe Project do
  subject(:project) { build(:project_with_deleted_output_dir, attr_hash) }

  let(:attr_hash) do
    {
      project_name: 'Images_jp2_tif',
      staging_location: 'spec/fixtures/images_jp2_tif'
    }
  end

  context 'validation' do
    it 'is not valid unless it has all required attributes' do
      expect(described_class.new).not_to be_valid
      expect(project).to be_valid
    end

    it 'is not valid without a User' do
      expect { project.user = nil }.to change(project, :valid?).to(false)
    end

    it 'is not valid unless staging_location exists on filesystem' do
      expect { project.staging_location = 'does/not/exist' }.to change(project, :valid?).to(false)
    end

    it { is_expected.to validate_presence_of(:content_structure) }
    it { is_expected.to validate_presence_of(:staging_location) }
    it { is_expected.to validate_presence_of(:processing_configuration) }
    it { is_expected.to validate_presence_of(:project_name) }

    context 'file_manifest required for media' do
      context 'when using_file_manifest is not selected' do
        let(:attr_hash) do
          {
            project_name: 'File_manifest_media',
            staging_location: 'spec/fixtures/media_audio_test',
            content_structure: 'media',
            using_file_manifest: false
          }
        end

        it 'is not valid' do
          expect(project.valid?).to be false
          expect(project.errors.size).to eq 1
          expect(project.errors.first.attribute).to eq :content_structure
        end
      end

      context 'when using_file_manifest is selected' do
        let(:attr_hash) do
          {
            project_name: 'File_manifest_media',
            staging_location: 'spec/fixtures/media_audio_test',
            content_structure: 'media',
            using_file_manifest: true
          }
        end

        it 'is valid' do
          expect(project.valid?).to be true
        end
      end
    end

    describe 'project_name' do
      it 'is not valid with chars other than alphanum, hyphen and underscore' do
        expect { project.project_name = 's p a c e s' }.to change(project, :valid?).to(false)
        project.project_name = "apostrophe's"
        expect(project.valid?).to be false
        project.project_name = 'quotes"'
        expect(project.valid?).to be false
      end

      it 'is valid with alphanum, hyphen and underscore chars' do
        valid_chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'
        expect { project.project_name = valid_chars }.not_to change(project, :valid?).from(true)
      end
    end

    context 'staging_location must be a sub dir of allowed parent directories' do
      it 'cannot jailbreak' do
        expect { project.staging_location = 'tmp/../../foo/' }.to change(project, :valid?).to(false)
      end

      it 'cannot use the root directly' do
        expect { project.staging_location = 'tmp/' }.to change(project, :valid?).to(false)
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
    is_expected.to define_enum_for(:processing_configuration).with_values(
      'default' => 0,
      'filename' => 1,
      'media_cm_style' => 2,
      'filename_with_ocr' => 3
    )
  end

  it { is_expected.to belong_to(:user) }

  it 'enums default to their default values' do
    project = described_class.new
    expect(project.content_structure).to eq 'simple_image'
    expect(project.processing_configuration).to eq 'default'
  end

  it 'staging_location has trailing slash removed' do
    expect(project.staging_location).to eq 'spec/fixtures/images_jp2_tif'
  end

  describe '#staging_location_with_path' do
    it 'creates a relative path' do
      expect(project.staging_location_with_path('manifest.csv')).to eq 'spec/fixtures/images_jp2_tif/manifest.csv'
    end
  end

  describe 'output_dir' do
    it 'returns "Settings.job_output_parent_dir/user_id/project_name"' do
      expect(project.output_dir).to eq "#{Settings.job_output_parent_dir}/#{project.user.email}/#{project.project_name}"
    end
  end

  describe '#progress_log_file' do
    it 'is project_name + "_progress.yml" in output_dir' do
      expect(project.progress_log_file).to eq "#{project.output_dir}/#{project.project_name}_progress.yml"
    end
  end

  describe '#object_manifest_rows' do
    context 'error' do
      context 'manifest missing' do
        let(:attr_hash) do
          {
            project_name: 'Images_jp2_tif',
            staging_location: 'spec/fixtures/exemplar_templates'
          }
        end

        it 'raises an error' do
          expect { project.object_manifest_rows }.to raise_error(RuntimeError, 'manifest file missing or empty')
        end
      end

      context 'manifest is an empty file' do
        let(:attr_hash) do
          {
            project_name: 'Images_jp2_tif',
            staging_location: 'spec/fixtures/manifest_empty'
          }
        end

        it 'raises an error' do
          expect { project.object_manifest_rows }.to raise_error(RuntimeError, 'manifest file missing or empty')
        end
      end

      context 'manifest with no header' do
        let(:attr_hash) do
          {
            project_name: 'Images_jp2_tif',
            staging_location: 'spec/fixtures/manifest_missing_header'
          }
        end

        it 'raises an error' do
          expect { project.object_manifest_rows }.to raise_error(RuntimeError, 'no rows in manifest or missing header')
        end
      end

      context 'manifest with header but no rows of data' do
        let(:attr_hash) do
          {
            project_name: 'Images_jp2_tif',
            staging_location: 'spec/fixtures/manifest_missing_rows'
          }
        end

        it 'raises an error' do
          expect { project.object_manifest_rows }.to raise_error(RuntimeError, 'no rows in manifest or missing header')
        end
      end

      context 'manifest with header but missing a required column' do
        let(:attr_hash) do
          {
            project_name: 'Images_jp2_tif',
            staging_location: 'spec/fixtures/manifest_missing_column'
          }
        end

        it 'raises an error' do
          expect { project.object_manifest_rows }.to raise_error(RuntimeError, 'manifest must have "druid" and "object" columns')
        end
      end
    end

    context 'success' do
      it 'loads the manifest CSV' do
        expect(CsvImporter).to receive(:parse_to_hash).with('spec/fixtures/images_jp2_tif/manifest.csv').and_call_original
        project.object_manifest_rows
      end

      it 'memoizes the manifest rows' do
        expect(CsvImporter).to receive(:parse_to_hash).once.with('spec/fixtures/images_jp2_tif/manifest.csv').and_call_original
        2.times { project.object_manifest_rows }
      end

      it 'expect the content of manifest rows' do
        expect(project.object_manifest_rows).to eq(
          [
            { 'druid' => 'druid:jy812bp9403', 'sourceid' => 'bar-1.0', 'object' => 'jy812bp9403', 'label' => 'Label 1', 'description' => 'This is a description for label 1' },
            { 'druid' => 'druid:tz250tk7584', 'sourceid' => 'bar-2.1', 'object' => 'tz250tk7584', 'label' => 'Label 2', 'description' => 'This is a description for label 2' },
            { 'druid' => 'druid:gn330dv6119', 'sourceid' => 'bar-3.1', 'object' => 'gn330dv6119', 'label' => 'Label 3', 'description' => 'This is a description for label 3' }
          ]
        )
      end
    end
  end

  describe '#output_dir_no_exists!' do
    before { FileUtils.mkdir_p(Settings.job_output_parent_dir) }

    after { FileUtils.rm_rf(project.output_dir) } # cleanup

    context 'when project is new' do
      before { allow(project).to receive(:persisted?).and_return(false) }

      it 'creates directory' do
        expect { project.send(:output_dir_no_exists!) }.to change { Dir.exist?(project.output_dir) }.from(false).to(true)
      end

      it 'adds error if directory already exists' do
        FileUtils.mkdir_p(project.output_dir)
        expect(project).to receive(:throw)
        project.send(:output_dir_no_exists!)
        expect(project.errors).not_to be_empty
      end

      it "adds error if directory can't be created" do
        allow(project).to receive(:output_dir).and_return('/bootx/foo')
        expect { project.send(:output_dir_no_exists!) }.to raise_error(SystemCallError, / @ dir_s_mkdir - \/bootx/)
      end
    end
  end

  describe '#output_dir_exists!' do
    context 'when project is not new' do
      before { allow(project).to receive(:persisted?).and_return(true) } # fake save

      it "adds error if directory doesn't exist" do
        expect(project).to receive(:throw)
        project.send(:output_dir_exists!)
        expect(project.errors).not_to be_empty
      end
    end
  end

  describe '#verify_staging_location' do
    it 'does nothing if staging_location already has errors' do
      project.errors.add(:staging_location, 'test')
      expect(File).not_to receive(:directory?)
      expect { project.send(:verify_staging_location) }.not_to change(project, :errors)
    end

    it 'adds error if missing manifest.csv' do
      allow(File).to receive(:exist?).with('spec/fixtures/images_jp2_tif/manifest.csv').and_return(false)
      project.send(:verify_staging_location)
      expect(project.errors.map(&:type)).to include('missing manifest: spec/fixtures/images_jp2_tif/manifest.csv')
    end
  end

  describe '#verify_file_manifest_exists' do
    context 'when not using a file manifest' do
      before { allow(project).to receive(:using_file_manifest).and_return(false) }

      it 'does nothing' do
        expect { project.send(:verify_file_manifest_exists) }.not_to change(project, :errors)
      end
    end

    context 'when using a file manifest' do
      before { allow(project).to receive(:using_file_manifest).and_return(true) }

      context 'when not found' do
        it 'adds error' do
          project.send(:verify_file_manifest_exists)
          expect(project.errors.map(&:type)).to include('missing or empty file manifest: spec/fixtures/images_jp2_tif/file_manifest.csv')
        end
      end

      context 'when empty' do
        let(:attr_hash) do
          {
            project_name: 'Empty_file_manifest',
            staging_location: 'spec/fixtures/manifest_empty'
          }
        end

        it 'adds error' do
          project.send(:verify_file_manifest_exists)
          expect(project.errors.map(&:type)).to include('missing or empty file manifest: spec/fixtures/manifest_empty/file_manifest.csv')
        end
      end

      context 'when valid' do
        let(:attr_hash) do
          {
            project_name: 'Hierarchical-files-with-file-manifest',
            staging_location: 'spec/fixtures/hierarchical-files-with-file-manifest'
          }
        end

        it 'does nothing' do
          expect { project.send(:verify_file_manifest_exists) }.not_to change(project, :errors)
        end
      end
    end
  end
end
