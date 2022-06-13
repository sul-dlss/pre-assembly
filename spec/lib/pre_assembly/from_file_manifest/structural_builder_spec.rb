# frozen_string_literal: true

RSpec.describe PreAssembly::FromFileManifest::StructuralBuilder do
  describe '#build' do
    subject(:structural) do
      described_class.build(cocina_dro: cocina_dro,
                            resources: resources,
                            object: content_dir,
                            staging_location: staging_location,
                            reading_order: 'left-to-right',
                            content_md_creation_style: :media)
    end

    let(:dro_access) { { view: 'world' } }
    let(:cocina_dro) do
      Cocina::RSpec::Factories.build(:dro, collection_ids: ['druid:bb000kk0000']).new(access: dro_access)
    end

    context 'with media style' do
      let(:content_dir) { 'vd000bj0000' }
      let(:staging_location) { Rails.root.join 'spec/test_data/media_video_test' }

      let(:resources) do
        { 1 =>
          { label: 'Video file 1',
            sequence: '1',
            resource_type: 'video',
            files: [{ file_extention: '.mp4',
                      filename: 'vd000bj0000_video_1.mp4',
                      label: 'Video file 1',
                      sequence: '1',
                      role: nil,
                      thumb: nil,
                      publish: 'yes',
                      shelve: 'yes',
                      preserve: 'yes',
                      resource_type: 'video' },
                    { file_extention: '.mpeg',
                      filename: 'vd000bj0000_video_1.mpeg',
                      label: 'Video file 1',
                      sequence: '1',
                      role: nil,
                      thumb: nil,
                      publish: 'no',
                      shelve: 'no',
                      preserve: 'yes',
                      resource_type: 'video' },
                    { file_extention: '.jp2',
                      filename: 'vd000bj0000_video_1_thumb.jp2',
                      label: 'Video file 1',
                      sequence: '1',
                      role: nil,
                      thumb: nil,
                      publish: 'yes',
                      shelve: 'yes',
                      preserve: 'yes',
                      resource_type: 'image' }] },
          2 =>
            { label: 'Video file 2',
              sequence: '2',
              resource_type: 'video',
              files: [{ file_extention: '.mp4',
                        filename: 'vd000bj0000_video_2.mp4',
                        label: 'Video file 2',
                        sequence: '2',
                        role: nil,
                        thumb: nil,
                        publish: 'yes',
                        shelve: 'yes',
                        preserve: 'yes',
                        resource_type: 'video' },
                      { file_extention: '.mpeg',
                        filename: 'vd000bj0000_video_2.mpeg',
                        label: 'Video file 2',
                        sequence: '2',
                        role: nil,
                        thumb: nil,
                        publish: 'no',
                        shelve: 'no',
                        preserve: 'yes',
                        resource_type: 'video' },
                      { file_extention: '.jp2',
                        filename: 'vd000bj0000_video_2_thumb.jp2',
                        label: 'Video file 2',
                        sequence: '2',
                        role: nil,
                        thumb: nil,
                        publish: 'yes',
                        shelve: 'yes',
                        preserve: 'yes',
                        resource_type: 'image' }] },
          3 =>
            { label: 'Image of media (1 of 2)',
              sequence: '3',
              resource_type: 'image',
              files: [{ file_extention: '.tif',
                        filename: 'vd000bj0000_video_img_1.tif',
                        label: 'Image of media (1 of 2)',
                        sequence: '3',
                        role: nil,
                        thumb: nil,
                        publish: 'no',
                        shelve: 'no',
                        preserve: 'yes',
                        resource_type: 'image' }] },
          4 =>
            { label: 'Image of media (2 of 2)',
              sequence: '4',
              resource_type: 'image',
              files: [{ file_extention: '.tif',
                        filename: 'vd000bj0000_video_img_2.tif',
                        label: 'Image of media (2 of 2)',
                        sequence: '4',
                        role: nil,
                        thumb: nil,
                        publish: 'no',
                        shelve: 'no',
                        preserve: 'yes',
                        resource_type: 'image' }] },
          5 =>
            { label: 'Disc log file',
              sequence: '5',
              resource_type: 'file',
              files: [{ file_extention: '.txt',
                        filename: 'vd000bj0000_video_log.txt',
                        label: 'Disc log file',
                        sequence: '5',
                        role: 'transcription',
                        thumb: nil,
                        publish: 'no',
                        shelve: 'no',
                        preserve: 'yes',
                        resource_type: 'file' }] } }
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
    end

    context 'with simple_book style' do
      let(:content_dir) { 'content' }
      let(:staging_location) { Rails.root.join 'spec/test_data/book-file-manifest' }

      let(:resources) do
        { 1 =>
            { label: 'page 1',
              sequence: '1',
              resource_type: 'page',
              files: [{ file_extention: '.jpg',
                        filename: 'page_0001.jpg',
                        label: 'page 1',
                        sequence: '1',
                        role: nil,
                        thumb: nil,
                        publish: 'no',
                        shelve: 'no',
                        preserve: 'yes',
                        resource_type: 'page' },
                      { file_extention: '.pdf',
                        filename: 'page_0001.pdf',
                        label: 'page 1',
                        sequence: '1',
                        role: nil,
                        thumb: nil,
                        publish: 'yes',
                        shelve: 'yes',
                        preserve: 'yes',
                        resource_type: 'page' },
                      { file_extention: '.xml',
                        filename: 'page_0001.xml',
                        label: 'page 1',
                        sequence: '1',
                        role: 'transcription',
                        thumb: nil,
                        publish: 'yes',
                        shelve: 'yes',
                        preserve: 'yes',
                        resource_type: 'page' }] },
          2 =>
            { label: 'page 2',
              sequence: '2',
              resource_type: 'page',
              files: [{ file_extention: '.jpg',
                        filename: 'page_0002.jpg',
                        label: 'page 2',
                        sequence: '2',
                        role: nil,
                        thumb: nil,
                        publish: 'no',
                        shelve: 'no',
                        preserve: 'yes',
                        resource_type: 'page' },
                      { file_extention: '.pdf',
                        filename: 'page_0002.pdf',
                        label: 'page 2',
                        sequence: '2',
                        role: nil,
                        thumb: nil,
                        publish: 'yes',
                        shelve: 'yes',
                        preserve: 'yes',
                        resource_type: 'page' },
                      { file_extention: '.xml',
                        filename: 'page_0002.xml',
                        label: 'page 2',
                        sequence: '2',
                        role: 'transcription',
                        thumb: nil,
                        publish: 'yes',
                        shelve: 'yes',
                        preserve: 'yes',
                        resource_type: 'page' }] },
          3 =>
            { label: 'page 3',
              sequence: '3',
              resource_type: 'page',
              files: [{ file_extention: '.jpg',
                        filename: 'page_0003.jpg',
                        label: 'page 3',
                        sequence: '3',
                        role: nil,
                        thumb: nil,
                        publish: 'no',
                        shelve: 'no',
                        preserve: 'yes',
                        resource_type: 'page' },
                      { file_extention: '.pdf',
                        filename: 'page_0003.pdf',
                        label: 'page 3',
                        sequence: '3',
                        role: nil,
                        thumb: nil,
                        publish: 'yes',
                        shelve: 'yes',
                        preserve: 'yes',
                        resource_type: 'page' },
                      { file_extention: '.xml',
                        filename: 'page_0003.xml',
                        label: 'page 3',
                        sequence: '3',
                        role: 'transcription',
                        thumb: nil,
                        publish: 'yes',
                        shelve: 'yes',
                        preserve: 'yes',
                        resource_type: 'page' }] } }
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
