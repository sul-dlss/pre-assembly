# frozen_string_literal: true

RSpec.describe PreAssembly::FromStagingLocation::StructuralBuilder do
  describe '#build' do
    subject(:structural) do
      described_class.build(cocina_dro:,
                            filesets:,
                            all_files_public:)
    end

    let(:filesets) { PreAssembly::FromStagingLocation::FileSetBuilder.build(processing_configuration: :default, objects:, style: :document) }
    let(:cocina_dro) do
      Cocina::RSpec::Factories.build(:dro, collection_ids: ['druid:bb000kk0000']).new(access: dro_access)
    end

    context 'with flat file structure' do
      let(:base_path) { 'spec/fixtures/pdf_document/content/' }
      let(:objects) { [PreAssembly::ObjectFile.new("#{base_path}document.pdf", { relative_path: 'document.pdf', file_attributes: { publish: 'yes', shelve: 'no', preserve: 'yes' } })] }

      context 'with all files public' do
        let(:dro_access) { { view: 'world' } }
        let(:all_files_public) { true }

        it 'adds all the files' do
          file_sets = structural.contains
          expect(file_sets.size).to eq 1
          files = file_sets.flat_map { |file_set| file_set.structural.contains }
          expect(files.map(&:filename)).to eq ['document.pdf']
          expected_access = { view: 'world', download: 'none', controlledDigitalLending: false }
          expect(files.map(&:access).map(&:to_h)).to all(eq(expected_access))

          # it stores administrative settings corresponding to the access
          expect(files.map { |file| file.administrative.to_h }).to all(eq({ publish: true, shelve: true, sdrPreserve: true }))

          # It retains the collection
          expect(structural.isMemberOf).to eq ['druid:bb000kk0000']
        end
      end

      context 'with world access' do
        let(:dro_access) { { view: 'world' } }
        let(:all_files_public) { false }

        it 'adds all the files' do
          file_sets = structural.contains
          expect(file_sets.size).to eq 1
          files = file_sets.flat_map { |file_set| file_set.structural.contains }
          expect(files.map(&:filename)).to eq ['document.pdf']
          expected_access = { view: 'world', download: 'none', controlledDigitalLending: false }
          expect(files.map(&:access).map(&:to_h)).to all(eq(expected_access))

          # it stores administrative settings based on the file_attributes
          expect(files.map { |file| file.administrative.to_h }).to all(eq({ publish: true, shelve: false, sdrPreserve: true }))

          # It retains the collection
          expect(structural.isMemberOf).to eq ['druid:bb000kk0000']
        end
      end

      context 'with dark access' do
        let(:dro_access) { { view: 'dark', download: 'none' } }
        let(:all_files_public) { false }

        it 'adds all the files' do
          file_sets = structural.contains
          expect(file_sets.size).to eq 1
          files = file_sets.flat_map { |file_set| file_set.structural.contains }
          expect(files.map(&:filename)).to eq ['document.pdf']
          expected_access = { view: 'dark', download: 'none', controlledDigitalLending: false }
          expect(files.map(&:access).map(&:to_h)).to all(eq(expected_access))

          # it stores administrative settings corresponding to the access
          expect(files.map { |file| file.administrative.to_h }).to all(eq({ publish: false, shelve: false, sdrPreserve: true }))

          # It retains the collection
          expect(structural.isMemberOf).to eq ['druid:bb000kk0000']
        end
      end
    end

    context 'with hierarchical file structure' do
      let(:base_path) { 'spec/fixtures/hierarchical-files/content/' }
      let(:objects) do
        [
          PreAssembly::ObjectFile.new("#{base_path}test1.txt", { relative_path: 'test1.txt', file_attributes: { publish: 'yes', shelve: 'no', preserve: 'yes' } }),
          PreAssembly::ObjectFile.new("#{base_path}/config/test.yml", { relative_path: '/config/test.yml', file_attributes: { publish: 'yes', shelve: 'no', preserve: 'yes' } }),
          PreAssembly::ObjectFile.new("#{base_path}/config/settings/test.yml", { relative_path: '/config/settings/test.yml', file_attributes: { publish: 'yes', shelve: 'no', preserve: 'yes' } }),
          PreAssembly::ObjectFile.new("#{base_path}/config/settings/test1.yml", { relative_path: '/config/settings/test1.yml', file_attributes: { publish: 'yes', shelve: 'no', preserve: 'yes' } }),
          PreAssembly::ObjectFile.new("#{base_path}/config/settings/test2.yml", { relative_path: '/config/settings/test2.yml', file_attributes: { publish: 'yes', shelve: 'no', preserve: 'yes' } }),
          PreAssembly::ObjectFile.new("#{base_path}/images/image.jpg", { relative_path: '/images/image.jpg', file_attributes: { publish: 'yes', shelve: 'no', preserve: 'yes' } }),
          PreAssembly::ObjectFile.new("#{base_path}/images/subdir/image.jpg", { relative_path: '/images/subdir/image.jpg', file_attributes: { publish: 'yes', shelve: 'no', preserve: 'yes' } })
        ]
      end

      context 'with all files public' do
        let(:dro_access) { { view: 'world' } }
        let(:all_files_public) { true }

        it 'adds all the files' do
          file_sets = structural.contains
          expect(file_sets.size).to eq 7
          files = file_sets.flat_map { |file_set| file_set.structural.contains }
          expect(files.map(&:filename)).to eq [
            'test1.txt',
            '/config/test.yml',
            '/config/settings/test.yml',
            '/config/settings/test1.yml',
            '/config/settings/test2.yml',
            '/images/image.jpg',
            '/images/subdir/image.jpg'
          ]
          expected_access = { view: 'world', download: 'none', controlledDigitalLending: false }
          expect(files.map(&:access).map(&:to_h)).to all(eq(expected_access))

          # it stores administrative settings corresponding to the access
          expect(files.map { |file| file.administrative.to_h }).to all(eq({ publish: true, shelve: true, sdrPreserve: true }))

          # It retains the collection
          expect(structural.isMemberOf).to eq ['druid:bb000kk0000']
        end
      end
    end
  end
end
