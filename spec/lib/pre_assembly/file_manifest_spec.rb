# frozen_string_literal: true

RSpec.describe PreAssembly::FileManifest do
  let(:staging_location) { Rails.root.join('spec/test_data/multimedia') }

  describe '#create_content_metadata' do
    context 'for a media object' do
      let(:bc_params) do
        {
          project_name: 'ProjectBar',
          staging_location: staging_location,
          content_metadata_creation: :default,
          content_structure: 'media',
          using_file_manifest: true
        }
      end
      let(:bc) { build(:batch_context, bc_params) }

      context 'without thumb declaration' do
        let(:dobj1) { setup_dobj('aa111aa1111', 'aa111aa1111', file_manifest) }
        let(:file_manifest) do
          described_class.new(csv_filename: 'file_manifest.csv', staging_location: staging_location)
        end

        let(:expected) do
          { contains: [
              {
                type: 'https://cocina.sul.stanford.edu/models/resources/media',
                externalIdentifier: 'aa111aa1111_1',
                label: 'Tape 1, Side A', version: 1,
                structural: {
                  contains: [
                    { type: 'https://cocina.sul.stanford.edu/models/file', externalIdentifier: 'https://cocina.sul.stanford.edu/file/1', label: 'aa111aa1111_001_a_pm.wav',
                      filename: 'aa111aa1111_001_a_pm.wav', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d1eea' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false }, administrative: { publish: false, sdrPreserve: true, shelve: false } },
                    { type: 'https://cocina.sul.stanford.edu/models/file', externalIdentifier: 'https://cocina.sul.stanford.edu/file/2', label: 'aa111aa1111_001_a_sh.wav',
                      filename: 'aa111aa1111_001_a_sh.wav', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d1eec' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false }, administrative: { publish: false, sdrPreserve: true, shelve: false } },
                    { type: 'https://cocina.sul.stanford.edu/models/file', externalIdentifier: 'https://cocina.sul.stanford.edu/file/3', label: 'aa111aa1111_001_a_sl.mp3',
                      filename: 'aa111aa1111_001_a_sl.mp3', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d0eea' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false }, administrative: { publish: true, sdrPreserve: true, shelve: true } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/4', label: 'aa111aa1111_001_img_1.jpg', filename: 'aa111aa1111_001_img_1.jpg', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d1eea' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: true, sdrPreserve: true, shelve: true } }
                  ]
                }
              }, {
                type: 'https://cocina.sul.stanford.edu/models/resources/file',
                externalIdentifier: 'aa111aa1111_2',
                label: 'Tape 1, Side B', version: 1,
                structural: {
                  contains: [
                    { type: 'https://cocina.sul.stanford.edu/models/file', externalIdentifier: 'https://cocina.sul.stanford.edu/file/5', label: 'aa111aa1111_001_b_pm.wav',
                      filename: 'aa111aa1111_001_b_pm.wav', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d1eea' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: true, sdrPreserve: true, shelve: true } },
                    { type: 'https://cocina.sul.stanford.edu/models/file', externalIdentifier: 'https://cocina.sul.stanford.edu/file/6', label: 'aa111aa1111_001_b_sh.wav',
                      filename: 'aa111aa1111_001_b_sh.wav', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d0eeb' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: false, sdrPreserve: false, shelve: false } },
                    { type: 'https://cocina.sul.stanford.edu/models/file', externalIdentifier: 'https://cocina.sul.stanford.edu/file/7', label: 'aa111aa1111_001_b_sl.mp3',
                      filename: 'aa111aa1111_001_b_sl.mp3', version: 1,
                      hasMessageDigests: [],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: true, sdrPreserve: true, shelve: true } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/8', label: 'aa111aa1111_001_img_2.jpg', filename: 'aa111aa1111_001_img_2.jpg', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d4eeb' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: true, sdrPreserve: true, shelve: true } }
                  ]
                }
              }, {
                type: 'https://cocina.sul.stanford.edu/models/resources/file',
                externalIdentifier: 'aa111aa1111_3',
                label: 'Transcript', version: 1,
                structural: {
                  contains: [
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/9', label: 'aa111aa1111.pdf', filename: 'aa111aa1111.pdf', version: 1,
                      hasMessageDigests: [],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: true, sdrPreserve: true, shelve: true } }
                  ]
                }
              }
            ],
            hasMemberOrders: [], isMemberOf: [] }
        end

        let(:dro) { Cocina::RSpec::Factories.build(:dro).new(access: { view: 'world' }) }

        let(:object_client) do
          instance_double(Dor::Services::Client::Object, find: dro, update: true)
        end

        before do
          allow(SecureRandom).to receive(:uuid).and_return('1', '2', '3', '4', '5', '6', '7', '8', '9')
          allow(Dor::Services::Client).to receive(:object).and_return(object_client)
        end

        it 'generates content metadata of type media from a file manifest with no thumb columns' do
          expect(dobj1.send(:build_structural).to_h).to eq expected
        end
      end
    end

    context 'for an image object' do
      let(:bc_params) do
        {
          project_name: 'ProjectBaz',
          staging_location: staging_location,
          content_metadata_creation: :default,
          content_structure: :simple_image,
          using_file_manifest: true
        }
      end
      let(:bc) { build(:batch_context, bc_params) }

      context 'without thumb declaration' do
        let(:dobj1) { setup_dobj('aa111aa1111', 'aa111aa1111', file_manifest) }
        let(:file_manifest) do
          described_class.new(csv_filename: 'file_manifest.csv', staging_location: staging_location)
        end

        let(:expected1) do
          { contains: [
              {
                type: 'https://cocina.sul.stanford.edu/models/resources/media',
                externalIdentifier: 'aa111aa1111_1',
                label: 'Tape 1, Side A', version: 1,
                structural: {
                  contains: [
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/1', label: 'aa111aa1111_001_a_pm.wav',
                      filename: 'aa111aa1111_001_a_pm.wav', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d1eea' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: false, sdrPreserve: true, shelve: false } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/2', label: 'aa111aa1111_001_a_sh.wav',
                      filename: 'aa111aa1111_001_a_sh.wav', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d1eec' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: false, sdrPreserve: true, shelve: false } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/3', label: 'aa111aa1111_001_a_sl.mp3',
                      filename: 'aa111aa1111_001_a_sl.mp3', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d0eea' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: true, sdrPreserve: true, shelve: true } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/4', label: 'aa111aa1111_001_img_1.jpg', filename: 'aa111aa1111_001_img_1.jpg', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d1eea' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: true, sdrPreserve: true, shelve: true } }
                  ]
                }
              }, {
                type: 'https://cocina.sul.stanford.edu/models/resources/file',
                externalIdentifier: 'aa111aa1111_2',
                label: 'Tape 1, Side B', version: 1,
                structural: {
                  contains: [
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/5', label: 'aa111aa1111_001_b_pm.wav',
                      filename: 'aa111aa1111_001_b_pm.wav', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d1eea' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: true, sdrPreserve: true, shelve: true } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/6', label: 'aa111aa1111_001_b_sh.wav',
                      filename: 'aa111aa1111_001_b_sh.wav', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d0eeb' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: false, sdrPreserve: false, shelve: false } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/7', label: 'aa111aa1111_001_b_sl.mp3',
                      filename: 'aa111aa1111_001_b_sl.mp3', version: 1,
                      hasMessageDigests: [],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: true, sdrPreserve: true, shelve: true } },
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/8',
                      label: 'aa111aa1111_001_img_2.jpg', filename: 'aa111aa1111_001_img_2.jpg', version: 1,
                      hasMessageDigests: [{ type: 'md5', digest: '0e80068efa7b0d749ed5da097f6d4eeb' }],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false }, administrative: { publish: true, sdrPreserve: true, shelve: true } }
                  ]
                }
              }, {
                type: 'https://cocina.sul.stanford.edu/models/resources/file',
                externalIdentifier: 'aa111aa1111_3',
                label: 'Transcript', version: 1,
                structural: {
                  contains: [
                    { type: 'https://cocina.sul.stanford.edu/models/file',
                      externalIdentifier: 'https://cocina.sul.stanford.edu/file/9',
                      label: 'aa111aa1111.pdf', filename: 'aa111aa1111.pdf', version: 1,
                      hasMessageDigests: [],
                      access: { view: 'world', download: 'none', controlledDigitalLending: false },
                      administrative: { publish: true, sdrPreserve: true, shelve: true } }
                  ]
                }
              }
            ],
            hasMemberOrders: [], isMemberOf: [] }
        end

        let(:dro) { Cocina::RSpec::Factories.build(:dro).new(access: { view: 'world' }) }

        let(:object_client) do
          instance_double(Dor::Services::Client::Object, find: dro, update: true)
        end

        before do
          allow(SecureRandom).to receive(:uuid).and_return('1', '2', '3', '4', '5', '6', '7', '8', '9')
          allow(Dor::Services::Client).to receive(:object).and_return(object_client)
        end

        it 'generates content metadata of type image from a file manifest with no thumb columns' do
          expect(dobj1.send(:build_structural).to_h).to eq expected1
        end
      end
    end
  end

  # some helper methods for these tests
  # rubocop:disable Metrics/AbcSize
  def setup_dobj(druid, object, file_manifest)
    allow(bc.batch).to receive(:file_manifest).and_return(file_manifest)
    PreAssembly::DigitalObject.new(bc.batch, container: object, stager: PreAssembly::CopyStager).tap do |dobj|
      allow(dobj).to receive(:pid).and_return("druid:#{druid}")
      allow(dobj).to receive(:content_md_creation).and_return('media_cm_style')
      allow(dobj).to receive(:object_type).and_return(Cocina::Models::ObjectType.media)
    end
  end
  # rubocop:enable Metrics/AbcSize
end
