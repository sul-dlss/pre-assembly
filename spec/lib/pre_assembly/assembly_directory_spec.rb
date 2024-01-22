# frozen_string_literal: true

RSpec.describe PreAssembly::AssemblyDirectory do
  context 'when something other than a geo object' do
    subject(:object) { described_class.new(druid_id: 'gn330dv6119', base_path: '/staging_path/', content_type: :simple_image) }

    describe '#druid_tree_dir' do
      it 'has the correct folders (using the contemporary style)' do
        expect(object.druid_tree_dir).to eq('tmp/assembly/gn/330/dv/6119/gn330dv6119')
      end
    end

    describe '#metadata_dir' do
      it 'has the correct folder (using the contemporary style)' do
        expect(object.send(:metadata_dir)).to eq('tmp/assembly/gn/330/dv/6119/gn330dv6119/metadata')
      end
    end

    describe '#content_dir' do
      it 'has the correct folder (using the contemporary style)' do
        expect(object.send(:content_dir)).to eq('tmp/assembly/gn/330/dv/6119/gn330dv6119/content')
      end
    end

    describe '#path_for' do
      it 'has the correct path for a file in the root of the folder' do
        expect(object.path_for('/staging_path/file.txt')).to eq('tmp/assembly/gn/330/dv/6119/gn330dv6119/content/file.txt')
      end

      it 'has the correct path for a file in a subfolder' do
        expect(object.path_for('/staging_path/some_folder/file.txt')).to eq('tmp/assembly/gn/330/dv/6119/gn330dv6119/content/some_folder/file.txt')
      end
    end
  end

  context 'when a geo object' do
    subject(:object) { described_class.new(druid_id: 'gn330dv6119', base_path: '/staging_path/', content_type: :geo) }

    describe '#druid_tree_dir' do
      it 'has the correct folders (using the geo style)' do
        expect(object.druid_tree_dir).to eq('tmp/gisassembly/gn330dv6119')
      end
    end

    describe '#metadata_dir' do
      it 'has the correct folder (using the geo style)' do
        expect(object.send(:metadata_dir)).to eq('tmp/gisassembly/gn330dv6119/metadata')
      end
    end

    describe '#content_dir' do
      it 'has the correct folder (using the geo style)' do
        expect(object.send(:content_dir)).to eq('tmp/gisassembly/gn330dv6119/content')
      end
    end

    describe '#path_for' do
      it 'has the correct path for a file in the root of the folder' do
        expect(object.path_for('/staging_path/file.txt')).to eq('tmp/gisassembly/gn330dv6119/content/file.txt')
      end

      it 'has the correct path for a file in a subfolder' do
        expect(object.path_for('/staging_path/some_folder/file.txt')).to eq('tmp/gisassembly/gn330dv6119/content/some_folder/file.txt')
      end
    end
  end
end
