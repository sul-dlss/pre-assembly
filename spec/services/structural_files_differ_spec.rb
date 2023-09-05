# frozen_string_literal: true

RSpec.describe StructuralFilesDiffer do
  describe '.diff' do
    let(:diff) { described_class.diff(existing_structural:, new_structural:, staging_location:, druid: 'aa111aa1111') }

    let(:staging_location) { Rails.root.join('spec/fixtures/multimedia') }

    let(:new_structural) do
      Cocina::Models::DROStructural.new(
        contains: [
          {
            type: 'https://cocina.sul.stanford.edu/models/resources/media',
            externalIdentifier: 'bc234fg5678_1',
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
            externalIdentifier: 'bc234fg5678_2',
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
                  administrative: { publish: false, sdrPreserve: true, shelve: false } },
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
            externalIdentifier: 'bc234fg5678_3',
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
        hasMemberOrders: [],
        isMemberOf: []
      )
    end

    let(:existing_structural) do
      Cocina::Models::DROStructural.new(
        contains: [
          {
            type: 'https://cocina.sul.stanford.edu/models/resources/media',
            externalIdentifier: 'bc234fg5678_1',
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
            externalIdentifier: 'bc234fg5678_2',
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
                  administrative: { publish: false, sdrPreserve: true, shelve: false } },
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
            externalIdentifier: 'bc234fg5678_3',
            label: 'Transcript', version: 1,
            structural: {
              contains: [
                { type: 'https://cocina.sul.stanford.edu/models/file',
                  # Changed the filename for test.
                  externalIdentifier: 'https://cocina.sul.stanford.edu/file/9', label: 'aa111aa1111.pdf', filename: 'xaa111aa1111.pdf', version: 1,
                  hasMessageDigests: [],
                  access: { view: 'world', download: 'none', controlledDigitalLending: false },
                  administrative: { publish: true, sdrPreserve: true, shelve: true } }
              ]
            }
          }
        ],
        hasMemberOrders: [],
        isMemberOf: []
      )
    end

    it 'returns diff' do
      expect(diff).to eq(
        {
          added_files: [
            'aa111aa1111.pdf'
          ],
          deleted_files: [
            'xaa111aa1111.pdf'
          ],
          updated_files: [
            'aa111aa1111_001_a_pm.wav',
            'aa111aa1111_001_a_sh.wav',
            'aa111aa1111_001_a_sl.mp3',
            'aa111aa1111_001_img_1.jpg',
            'aa111aa1111_001_b_pm.wav',
            'aa111aa1111_001_b_sh.wav',
            'aa111aa1111_001_b_sl.mp3',
            'aa111aa1111_001_img_2.jpg'
          ]
        }
      )
    end
  end
end
