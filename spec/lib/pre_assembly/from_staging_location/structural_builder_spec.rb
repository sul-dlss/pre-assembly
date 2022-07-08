# frozen_string_literal: true

RSpec.describe PreAssembly::FromStagingLocation::StructuralBuilder do
  describe '#build' do
    subject(:structural) do
      described_class.build(cocina_dro: cocina_dro,
                            filesets: filesets,
                            common_path: common_path,
                            all_files_public: all_files_public,
                            reading_order: 'left-to-right',
                            content_md_creation_style: :document)
    end

    let(:common_path) { 'spec/test_data/pdf_document/content/' }
    let(:objects) { [PreAssembly::ObjectFile.new("#{common_path}document.pdf", { file_attributes: { publish: 'yes', shelve: 'no', preserve: 'yes' } })] }
    let(:filesets) { PreAssembly::FromStagingLocation::FileSetBuilder.build(bundle: :default, objects: objects, style: :document) }
    let(:cocina_dro) do
      Cocina::RSpec::Factories.build(:dro, collection_ids: ['druid:bb000kk0000']).new(access: dro_access)
    end

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
end