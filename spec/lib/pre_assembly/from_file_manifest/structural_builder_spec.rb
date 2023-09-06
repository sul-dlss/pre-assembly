# frozen_string_literal: true

RSpec.describe PreAssembly::FromFileManifest::StructuralBuilder do
  describe '#build' do
    subject(:structural) do
      described_class.build(cocina_dro:, resources:, staging_location:)
    end

    let(:dro_access) { { view: 'world' } }
    let(:dro_structural) { { contains: [], isMemberOf: ['druid:bb000kk0000'] } }
    let(:cocina_dro) do
      Cocina::RSpec::Factories.build(:dro, id: 'druid:vd000bj0000').new(access: dro_access, structural: dro_structural)
    end

    context 'with media style' do
      let(:staging_location) { Rails.root.join('spec/fixtures/media_video_test').to_s }
      let(:content_dir) { 'vd000bj0000' }

      let(:resources) do
        { file_sets: { 1 =>
          { label: 'Video file 1',
            sequence: 1,
            resource_type: 'video',
            files: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/f3e1c208-a79a-49f6-9f26-784cf80ad445',
                      filename: 'vd000bj0000_video_1.mp4',
                      label: 'vd000bj0000_video_1.mp4',
                      administrative: { sdrPreserve: true, publish: true, shelve: true },
                      hasMessageDigests: [{ type: 'md5', digest: 'ee4e90be549c5614ac6282a5b80a506b' }] },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/2e4fa62a-c4b5-410a-a64c-fb3fb543aebd',
                      filename: 'vd000bj0000_video_1.mpeg',
                      label: 'vd000bj0000_video_1.mpeg',
                      administrative: { sdrPreserve: true, publish: false, shelve: false },
                      hasMessageDigests: [{ type: 'md5', digest: 'bed85c6ffc2f8070599a7fb682852f30' }] },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/e32b449a-847f-4765-8f08-d06c8dd3b09f',
                      filename: 'vd000bj0000_video_1_thumb.jp2',
                      label: 'vd000bj0000_video_1_thumb.jp2',
                      administrative: { sdrPreserve: true, publish: true, shelve: true },
                      hasMessageDigests: [{ type: 'md5', digest: '4b0e92aec76da9ac98567b8e6848e922' }] }] },
                       2 =>
          { label: 'Video file 2',
            sequence: 2,
            resource_type: 'video',
            files: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/8724fec6-6113-4682-8660-f18caef70f1b',
                      filename: 'vd000bj0000_video_2.mp4',
                      label: 'vd000bj0000_video_2.mp4',
                      administrative: { sdrPreserve: true, publish: true, shelve: true },
                      hasMessageDigests: [{ type: 'md5', digest: 'ee4e90be549c5614ac6282a5b80a506b' }] },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/6212c030-8e29-4d6f-9b43-d68302be31a5',
                      filename: 'vd000bj0000_video_2.mpeg',
                      label: 'vd000bj0000_video_2.mpeg',
                      administrative: { sdrPreserve: true, publish: false, shelve: false },
                      hasMessageDigests: [{ type: 'md5', digest: 'bed85c6ffc2f8070599a7fb682852f30' }] },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/e8bf293d-9efa-4946-ba58-988ecc30fd0e',
                      filename: 'vd000bj0000_video_2_thumb.jp2',
                      label: 'vd000bj0000_video_2_thumb.jp2',
                      administrative: { sdrPreserve: true, publish: true, shelve: true },
                      hasMessageDigests: [{ type: 'md5', digest: '4b0e92aec76da9ac98567b8e6848e922' }] }] },
                       3 =>
          { label: 'Image of media (1 of 2)',
            sequence: 3,
            resource_type: 'image',
            files: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/297e093a-8563-4e57-998d-c1b7b12d6e6a',
                      filename: 'vd000bj0000_video_img_1.tif',
                      label: 'vd000bj0000_video_img_1.tif',
                      administrative: { sdrPreserve: true, publish: false, shelve: false },
                      hasMessageDigests: [{ type: 'md5', digest: '4fe3ad7bf975326ff1c1271e8f743ceb' }] }] },
                       4 =>
          { label: 'Image of media (2 of 2)',
            sequence: 4,
            resource_type: 'image',
            files: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/a6c11765-9a36-4981-b98b-2a59940e97a3',
                      filename: 'vd000bj0000_video_img_2.tif',
                      label: 'vd000bj0000_video_img_2.tif',
                      administrative: { sdrPreserve: true, publish: false, shelve: false },
                      hasMessageDigests: [{ type: 'md5', digest: '4fe3ad7bf975326ff1c1271e8f743ceb' }] }] },
                       5 =>
          { label: 'Disc log file',
            sequence: 5,
            resource_type: 'file',
            files: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/be20e848-afe0-4e41-9ead-ae718ab61dcd',
                      filename: 'vd000bj0000_video_log.txt',
                      label: 'vd000bj0000_video_log.txt',
                      use: 'transcription',
                      administrative: { sdrPreserve: true, publish: false, shelve: false },
                      hasMessageDigests: [{ type: 'md5', digest: 'b659a852e4f0faa2f1d83973446a4ee9' }] }] } } }
      end

      it 'adds all the files' do
        file_sets = structural.contains
        expect(file_sets.size).to eq 5
        files = file_sets.flat_map { |file_set| file_set.structural.contains }
        expect(files.map(&:filename)).to eq ['vd000bj0000_video_1.mp4',
                                             'vd000bj0000_video_1.mpeg', 'vd000bj0000_video_1_thumb.jp2',
                                             'vd000bj0000_video_2.mp4', 'vd000bj0000_video_2.mpeg',
                                             'vd000bj0000_video_2_thumb.jp2', 'vd000bj0000_video_img_1.tif',
                                             'vd000bj0000_video_img_2.tif', 'vd000bj0000_video_log.txt']
        expected_access = { view: 'world', download: 'none', controlledDigitalLending: false }
        expect(files.map(&:access).map(&:to_h)).to all(eq(expected_access))

        # The digests are imported from the filesystem if present:
        expect(files.first.hasMessageDigests.first.to_h).to eq({ type: 'md5', digest: 'ee4e90be549c5614ac6282a5b80a506b' })

        # it stores administrative settings from the file manifest
        expect(files.last.administrative.to_h).to eq({ publish: false, shelve: false, sdrPreserve: true })

        # It retains the collection
        expect(structural.isMemberOf).to eq ['druid:bb000kk0000']
      end

      context 'when file manifest has additions, deletions, and updates' do
        let(:resources) do
          { file_sets: { 1 =>
            { label: 'Video file 1',
              sequence: 1,
              resource_type: 'video',
              files: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                        externalIdentifier: 'https://cocina.sul.stanford.edu/file/f3e1c208-a79a-49f6-9f26-784cf80ad445',
                        # Not in the cocina structural, meaning this file was added.
                        filename: 'vd000bj0000_video_1.mp4',
                        label: 'vd000bj0000_video_1.mp4',
                        administrative: { sdrPreserve: true, publish: true, shelve: true },
                        hasMessageDigests: [{ type: 'md5', digest: 'ee4e90be549c5614ac6282a5b80a506b' }] },
                      { type: 'https://cocina.sul.stanford.edu/models/file',
                        externalIdentifier: 'https://cocina.sul.stanford.edu/file/2e4fa62a-c4b5-410a-a64c-fb3fb543aebd',
                        # In cocina structural but not on disk, meaning this file is unchanged.
                        filename: 'x-vd000bj0000_video_1.mpeg',
                        label: 'vd000bj0000_video_1.mpeg',
                        administrative: { sdrPreserve: true, publish: false, shelve: false },
                        hasMessageDigests: [{ type: 'md5', digest: 'bed85c6ffc2f8070599a7fb682852f30' }] },
                      { type: 'https://cocina.sul.stanford.edu/models/file',
                        externalIdentifier: 'https://cocina.sul.stanford.edu/file/e32b449a-847f-4765-8f08-d06c8dd3b09f',
                        # Both in cocina structural and on disk, meaning this file was updated.
                        filename: 'vd000bj0000_video_1_thumb.jp2',
                        label: 'vd000bj0000_video_1_thumb.jp2',
                        administrative: { sdrPreserve: true, publish: true, shelve: true },
                        hasMessageDigests: [{ type: 'md5', digest: '4b0e92aec76da9ac98567b8e6848e922' }] }] } } }
        end

        let(:dro_structural) do
          { contains: [{ type: 'https://cocina.sul.stanford.edu/models/resources/video',
                         externalIdentifier: 'bc234fg5678_1',
                         label: 'Video file 1',
                         version: 1,
                         structural: { contains: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                                                    externalIdentifier: 'https://cocina.sul.stanford.edu/file/f3e1c208-a79a-49f6-9f26-784cf80ad445',
                                                    label: 'vd000bj0000_video_1.mp4',
                                                    # Not in the file manifest, meaning this file was deleted.
                                                    filename: 'x-vd000bj0000_video_1.mp4',
                                                    version: 1,
                                                    hasMessageDigests: [{ type: 'md5', digest: 'ee4e90be549c5614ac6282a5b80a506b' }],
                                                    access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                    administrative: { publish: true, sdrPreserve: true, shelve: true } },
                                                  { type: 'https://cocina.sul.stanford.edu/models/file',
                                                    externalIdentifier: 'https://cocina.sul.stanford.edu/file/2e4fa62a-c4b5-410a-a64c-fb3fb543aebd',
                                                    label: 'vd000bj0000_video_1.mpeg',
                                                    # Exists in file manifest, but not on disk. Note that the md5 is changed to make sure it is maintained.
                                                    filename: 'x-vd000bj0000_video_1.mpeg',
                                                    version: 1,
                                                    hasMessageDigests: [{ type: 'md5', digest: 'x-bed85c6ffc2f8070599a7fb682852f30' }],
                                                    # Mimetype, size, and presentation added to make sure it is maintained.
                                                    hasMimeType: 'image/jp2',
                                                    size: 1234,
                                                    presentation: { height: 123, width: 456 },
                                                    access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                    administrative: { publish: false, sdrPreserve: true, shelve: false } },
                                                  { type: 'https://cocina.sul.stanford.edu/models/file',
                                                    externalIdentifier: 'https://cocina.sul.stanford.edu/file/e32b449a-847f-4765-8f08-d06c8dd3b09f',
                                                    label: 'vd000bj0000_video_1_thumb.jp2',
                                                    # Exists in file manifest and on disk, meaning it is updated. Note that the md5 is changed to make sure it is not maintained.
                                                    filename: 'vd000bj0000_video_1_thumb.jp2',
                                                    version: 1,
                                                    hasMessageDigests: [{ type: 'md5', digest: 'x-4b0e92aec76da9ac98567b8e6848e922' }],
                                                    # Mimetype, size, and presentation added to make sure it is not maintained.
                                                    hasMimeType: 'image/jp2',
                                                    size: 1234,
                                                    presentation: { height: 123, width: 456 },
                                                    access: { view: 'world', download: 'none', controlledDigitalLending: false },
                                                    administrative: { publish: true, sdrPreserve: true, shelve: true } }] } }],
            hasMemberOrders: [],
            isMemberOf: ['druid:bb000kk0000'] }
        end

        it 'generates the structural with changes' do
          file_sets = structural.contains
          expect(file_sets.size).to eq 1
          files = file_sets.flat_map { |file_set| file_set.structural.contains }
          expect(files.map(&:filename)).to eq ['vd000bj0000_video_1.mp4',
                                               'x-vd000bj0000_video_1.mpeg',
                                               'vd000bj0000_video_1_thumb.jp2']
          unchanged_file = files[1]
          expect(unchanged_file.hasMimeType).to eq 'image/jp2'
          expect(unchanged_file.size).to eq 1234
          expect(unchanged_file.presentation.to_h).to eq(height: 123, width: 456)
          expect(unchanged_file.hasMessageDigests.first.digest).to eq 'x-bed85c6ffc2f8070599a7fb682852f30'

          updated_file = files[2]
          expect(updated_file.hasMimeType).to be_nil
          expect(updated_file.size).to be_nil
          expect(updated_file.presentation).to be_nil
          expect(updated_file.hasMessageDigests.first.digest).to eq '4b0e92aec76da9ac98567b8e6848e922'
        end
      end
    end

    context 'with simple_book style' do
      let(:staging_location) { Rails.root.join('spec/fixtures/book-file-manifest').to_s }
      let(:content_dir) { 'content' }

      let(:resources) do
        { file_sets: { 1 =>
          { label: 'page 1',
            sequence: 1,
            resource_type: 'page',
            files: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/089523b5-caa0-4838-9d48-1d9d918863c7',
                      filename: 'page_0001.jpg',
                      label: 'page_0001.jpg',
                      administrative: { sdrPreserve: true, publish: false, shelve: false } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/6499ae75-ecf8-4e08-8c6e-b53b038424a1',
                      filename: 'page_0001.pdf',
                      label: 'page_0001.pdf',
                      administrative: { sdrPreserve: true, publish: true, shelve: true } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/b1e7b5c0-cc03-416a-899c-327e7cd1b3f2',
                      filename: 'page_0001.xml',
                      label: 'page_0001.xml',
                      use: 'transcription',
                      administrative: { sdrPreserve: true, publish: true, shelve: true } }] },
                       2 =>
          { label: 'page 2',
            sequence: 2,
            resource_type: 'page',
            files: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/3cdc72bd-ddf9-4aae-acae-5e2ccec82ade',
                      filename: 'page_0002.jpg',
                      label: 'page_0002.jpg',
                      administrative: { sdrPreserve: true, publish: false, shelve: false } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/f1aecba5-83ef-48bd-b7bd-53e1dd575596',
                      filename: 'page_0002.pdf',
                      label: 'page_0002.pdf',
                      administrative: { sdrPreserve: true, publish: true, shelve: true } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/8a460771-52ca-46cb-82ee-b5557e4b8894',
                      filename: 'page_0002.xml',
                      label: 'page_0002.xml',
                      use: 'transcription',
                      administrative: { sdrPreserve: true, publish: true, shelve: true } }] },
                       3 =>
          { label: 'page 3',
            sequence: 3,
            resource_type: 'page',
            files: [{ type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/0d7a3f3a-d099-46f4-b526-49dc1a61f947',
                      filename: 'page_0003.jpg',
                      label: 'page_0003.jpg',
                      administrative: { sdrPreserve: true, publish: false, shelve: false } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/3c6b46e7-cf0a-46d1-834d-bcfdd3679fd9',
                      filename: 'page_0003.pdf',
                      label: 'page_0003.pdf',
                      administrative: { sdrPreserve: true, publish: true, shelve: true } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/868dad5f-bb6e-4f69-b7e3-c1ccba96eda3',
                      filename: 'page_0003.xml',
                      label: 'page_0003.xml',
                      use: 'transcription',
                      administrative: { sdrPreserve: true, publish: true, shelve: true } }] } } }
      end

      it 'adds all the files' do
        file_sets = structural.contains
        expect(file_sets.size).to eq 3
        files = file_sets.flat_map { |file_set| file_set.structural.contains }
        expect(files.map(&:filename)).to eq [
          'page_0001.jpg',
          'page_0001.pdf',
          'page_0001.xml',
          'page_0002.jpg',
          'page_0002.pdf',
          'page_0002.xml',
          'page_0003.jpg',
          'page_0003.pdf',
          'page_0003.xml'
        ]
        expected_access = { view: 'world', download: 'none', controlledDigitalLending: false }
        expect(files.map(&:access).map(&:to_h)).to all(eq(expected_access))
      end
    end
  end
end
