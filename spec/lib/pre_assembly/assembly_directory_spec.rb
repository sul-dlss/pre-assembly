# frozen_string_literal: true

RSpec.describe PreAssembly::AssemblyDirectory do
  subject(:object) { described_class.new(druid_id: 'gn330dv6119') }

  describe 'druid tree' do
    it 'has the correct folders (using the contemporary style)' do
      expect(object.druid_tree_dir).to eq('tmp/assembly/gn/330/dv/6119/gn330dv6119')
      expect(object.send(:metadata_dir)).to eq('tmp/assembly/gn/330/dv/6119/gn330dv6119/metadata')
      expect(object.send(:content_dir)).to eq('tmp/assembly/gn/330/dv/6119/gn330dv6119/content')
    end
  end
end
