# frozen_string_literal: true

RSpec.describe ObjectFileFinder do
  describe '#run' do
    subject { finder.run.map(&:path) }

    let(:finder) { described_class.new(stageable_items: stageable_items, druid: 'oo000oo0000') }

    let(:files) do
      [
        'spec/test_data/images_jp2_tif/gn330dv6119/image1.jp2',
        'spec/test_data/images_jp2_tif/gn330dv6119/image1.tif',
        'spec/test_data/images_jp2_tif/gn330dv6119/image2.jp2',
        'spec/test_data/images_jp2_tif/gn330dv6119/image2.tif',
        'spec/test_data/images_jp2_tif/jy812bp9403/00/image1.tif',
        'spec/test_data/images_jp2_tif/jy812bp9403/00/image2.tif',
        'spec/test_data/images_jp2_tif/jy812bp9403/05/image1.jp2',
        'spec/test_data/images_jp2_tif/tz250tk7584/00/image1.tif',
        'spec/test_data/images_jp2_tif/tz250tk7584/00/image2.tif'
      ]
    end

    context 'when files are provided as stageable items' do
      let(:stageable_items) { files }

      it { is_expected.to eq files }
    end

    context 'when directories are provided as stageable items' do
      let(:stageable_items) do
        ['spec/test_data/images_jp2_tif/gn330dv6119', 'spec/test_data/images_jp2_tif/jy812bp9403', 'spec/test_data/images_jp2_tif/tz250tk7584']
      end

      it { is_expected.to eq files }
    end
  end

  describe '#base_dir' do
    let(:finder) { described_class.new(stageable_items: [], druid: 'foo') }

    it 'returns expected value' do
      expect(finder.send(:base_dir, 'foo/bar/fubb.txt')).to eq('foo/bar')
    end

    it 'raises error if given bogus arguments' do
      exp_msg = /^Bad arg to get_base_dir/
      expect { finder.send(:base_dir, 'foo.txt')     }.to raise_error(ArgumentError, exp_msg)
      expect { finder.send(:base_dir, '')            }.to raise_error(ArgumentError, exp_msg)
      expect { finder.send(:base_dir, 'x\y\foo.txt') }.to raise_error(ArgumentError, exp_msg)
    end
  end

  describe '#new_object_file' do
    let(:finder) { described_class.new(stageable_items: [], druid: 'foo') }

    it 'returns an ObjectFile with expected path values' do
      tests = [
        # Stageable is a file:
        # - immediately in bundle dir.
        { stageable: 'BUNDLE/x.tif',
          file_path: 'BUNDLE/x.tif',
          exp_rel_path: 'x.tif' },
        # - within subdir of bundle dir.
        { stageable: 'BUNDLE/a/b/x.tif',
          file_path: 'BUNDLE/a/b/x.tif',
          exp_rel_path: 'x.tif' },
        # Stageable is a directory:
        # - immediately in bundle dir
        { stageable: 'BUNDLE/a',
          file_path: 'BUNDLE/a/x.tif',
          exp_rel_path: 'a/x.tif' },
        # - immediately in bundle dir, with file deeper
        { stageable: 'BUNDLE/a',
          file_path: 'BUNDLE/a/b/x.tif',
          exp_rel_path: 'a/b/x.tif' },
        # - within a subdir of bundle dir
        { stageable: 'BUNDLE/a/b',
          file_path: 'BUNDLE/a/b/x.tif',
          exp_rel_path: 'b/x.tif' },
        # - within a subdir of bundle dir, with file deeper
        { stageable: 'BUNDLE/a/b',
          file_path: 'BUNDLE/a/b/c/d/x.tif',
          exp_rel_path: 'b/c/d/x.tif' }
      ]
      tests.each do |t|
        ofile = finder.send(:new_object_file, t[:stageable], t[:file_path])
        expect(ofile).to be_a PreAssembly::ObjectFile
        expect(ofile.path).to eq t[:file_path]
        expect(ofile.relative_path).to eq t[:exp_rel_path]
      end
    end
  end

  describe '#find_files_recursively' do
    subject { finder.send(:find_files_recursively, staging_location).sort }

    let(:finder) { described_class.new(stageable_items: [], druid: 'foo') }
    let(:staging_location) { batch_context_from_hash(type).staging_location }

    context 'with flat_dir_images' do
      let(:type) { :flat_dir_images }

      it {
        is_expected.to eq [
          'spec/test_data/flat_dir_images/checksums.txt',
          'spec/test_data/flat_dir_images/image1.tif',
          'spec/test_data/flat_dir_images/image2.tif',
          'spec/test_data/flat_dir_images/image3.tif',
          'spec/test_data/flat_dir_images/manifest.csv',
          'spec/test_data/flat_dir_images/manifest_badsourceid_column.csv'
        ]
      }
    end

    context 'with images_jp2_tif' do
      let(:type) { :images_jp2_tif }

      it {
        is_expected.to eq [
          'spec/test_data/images_jp2_tif/gn330dv6119/image1.jp2',
          'spec/test_data/images_jp2_tif/gn330dv6119/image1.tif',
          'spec/test_data/images_jp2_tif/gn330dv6119/image2.jp2',
          'spec/test_data/images_jp2_tif/gn330dv6119/image2.tif',
          'spec/test_data/images_jp2_tif/jy812bp9403/00/image1.tif',
          'spec/test_data/images_jp2_tif/jy812bp9403/00/image2.tif',
          'spec/test_data/images_jp2_tif/jy812bp9403/05/image1.jp2',
          'spec/test_data/images_jp2_tif/manifest.csv',
          'spec/test_data/images_jp2_tif/tz250tk7584/00/image1.tif',
          'spec/test_data/images_jp2_tif/tz250tk7584/00/image2.tif'
        ]
      }
    end
  end
end
