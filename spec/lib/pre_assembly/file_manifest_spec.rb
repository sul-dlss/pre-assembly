# frozen_string_literal: true

RSpec.describe PreAssembly::FileManifest do
  let(:file_manifest) do
    described_class.new(csv_filename:, staging_location:)
  end

  describe '#manifest' do
    let(:staging_location) { Rails.root.join('spec/fixtures/media_missing') }

    context 'when no rows' do
      let(:csv_filename) { "#{staging_location}/file_manifest_no_rows.csv" }

      it 'throws an exception' do
        expect { described_class.new(staging_location:, csv_filename:).manifest }.to raise_error(RuntimeError, 'no rows in file_manifest or missing header')
      end
    end

    context 'when invalid rows' do
      let(:csv_filename) { "#{staging_location}/file_manifest_invalid.csv" }

      it 'throws an exception' do
        expect { described_class.new(staging_location:, csv_filename:).manifest }.to raise_error(RuntimeError, 'file_manifest has preserve and shelve both being set to no for a single file')
      end
    end

    context 'when missing columns' do
      let(:csv_filename) { "#{staging_location}/file_manifest_missing_columns.csv" }

      it 'throws an exception' do
        expect { described_class.new(staging_location:, csv_filename:).manifest }.to raise_error(RuntimeError, 'file_manifest missing required columns')
      end
    end
  end

  describe '#create_content_metadata' do
    let(:staging_location) { Rails.root.join('spec/fixtures/multimedia') }

    let(:structural) do
      file_manifest.generate_structure(cocina_dro: dro, object: 'aa111aa1111')
    end

    let(:dro) { Cocina::RSpec::Factories.build(:dro).new(access: { view: 'world' }) }

    before do
      allow(SecureRandom).to receive(:uuid).and_return('1', '2', '3', '4', '5', '6', '7', '8', '9')
    end

    # These are fields that were in common use prior to alignment with Argo manifest
    context 'with classic file manifest fields' do
      let(:csv_filename) { File.join(staging_location, 'file_manifest.csv') }

      let(:expected_structural) do
        { contains: [
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
          hasMemberOrders: [], isMemberOf: [] }
      end

      it 'generates content metadata' do
        expect(structural.to_h).to eq expected_structural
      end
    end
  end
end
