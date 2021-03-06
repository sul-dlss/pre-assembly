# frozen_string_literal: true

RSpec.describe PreAssembly::FileManifest do
  let(:bundle_dir) { Rails.root.join('spec/test_data/multimedia') }

  describe '#create_content_metadata' do
    context 'for a media object' do
      let(:bc_params) do
        {
          project_name: 'ProjectBar',
          bundle_dir: bundle_dir,
          content_metadata_creation: :default,
          content_structure: 'media',
          using_file_manifest: true
        }
      end
      let(:bc) { build(:batch_context, bc_params) }

      context 'without thumb declaration' do
        let(:dobj1) { setup_dobj('aa111aa1111', 'aa111aa1111', file_manifest) }
        let(:dobj2) { setup_dobj('bb222bb2222', 'object2', file_manifest) }
        let(:file_manifest) do
          described_class.new(csv_filename: 'file_manifest.csv', bundle_dir: bundle_dir)
        end

        it 'generates content metadata of type media from a file manifest with no thumb columns' do
          expect(noko_doc(dobj1.send(:create_content_metadata, false))).to be_equivalent_to noko_doc(exp_xml_object_aa111aa1111)
          expect(noko_doc(dobj2.send(:create_content_metadata, true))).to be_equivalent_to noko_doc(exp_xml_object_bb222bb2222)
        end
      end

      context 'with thumb declaration' do
        it 'generates content metadata of type media from a file manifest with a thumb column set to yes' do
          file_manifest = described_class.new(csv_filename: 'file_manifest_with_thumb.csv', bundle_dir: bundle_dir)
          dobj1 = setup_dobj('aa111aa1111', 'aa111aa1111', file_manifest)
          dobj2 = setup_dobj('bb222bb2222', 'object2', file_manifest)

          expect(noko_doc(dobj1.send(:create_content_metadata, true))).to be_equivalent_to noko_doc(exp_xml_object_aa111aa1111_with_thumb)
          expect(noko_doc(dobj2.send(:create_content_metadata, false))).to be_equivalent_to noko_doc(exp_xml_object_bb222bb2222)
        end

        it 'generates content metadata of type media from a file manifest with a thumb column set to true' do
          file_manifest = described_class.new(csv_filename: 'file_manifest_with_thumb_true.csv', bundle_dir: bundle_dir)
          dobj1 = setup_dobj('aa111aa1111', 'aa111aa1111', file_manifest)
          dobj2 = setup_dobj('bb222bb2222', 'object2', file_manifest)

          expect(noko_doc(dobj1.send(:create_content_metadata, false))).to be_equivalent_to noko_doc(exp_xml_object_aa111aa1111_with_thumb)
          expect(noko_doc(dobj2.send(:create_content_metadata, true))).to be_equivalent_to noko_doc(exp_xml_object_bb222bb2222)
        end

        it 'generates content metadata of type media from a file manifest with no thumbs when the thumb column is set to no' do
          file_manifest = described_class.new(csv_filename: 'file_manifest_thumb_no.csv', bundle_dir: bundle_dir)
          dobj1 = setup_dobj('aa111aa1111', 'aa111aa1111', file_manifest)
          dobj2 = setup_dobj('bb222bb2222', 'object2', file_manifest)

          expect(noko_doc(dobj1.send(:create_content_metadata, true))).to be_equivalent_to noko_doc(exp_xml_object_aa111aa1111)
          expect(noko_doc(dobj2.send(:create_content_metadata, false))).to be_equivalent_to noko_doc(exp_xml_object_bb222bb2222)
        end
      end
    end

    context 'for an image object' do
      let(:bc_params) do
        {
          project_name: 'ProjectBaz',
          bundle_dir: bundle_dir,
          content_metadata_creation: :default,
          content_structure: :simple_image,
          using_file_manifest: true
        }
      end
      let(:bc) { build(:batch_context, bc_params) }

      context 'without thumb declaration' do
        let(:dobj1) { setup_dobj('aa111aa1111', 'aa111aa1111', file_manifest) }
        let(:dobj2) { setup_dobj('bb222bb2222', 'object2', file_manifest) }
        let(:file_manifest) do
          described_class.new(csv_filename: 'file_manifest.csv', bundle_dir: bundle_dir)
        end

        it 'generates content metadata of type image from a file manifest with no thumb columns' do
          expect(noko_doc(dobj1.send(:create_content_metadata, false))).to be_equivalent_to noko_doc(exp_xml_image_object_aa111aa1111)
          expect(noko_doc(dobj2.send(:create_content_metadata, true))).to be_equivalent_to noko_doc(exp_xml_image_object_bb222bb2222)
        end
      end
    end
  end

  # some helper methods for these tests
  def setup_dobj(druid, object, file_manifest)
    allow(bc.batch).to receive(:file_manifest).and_return(file_manifest)
    PreAssembly::DigitalObject.new(bc.batch, container: object, stager: PreAssembly::CopyStager, dark: false).tap do |dobj|
      allow(dobj).to receive(:pid).and_return("druid:#{druid}")
      allow(dobj).to receive(:content_md_creation).and_return('media_cm_style')
      allow(dobj).to receive(:using_file_manifest).and_return(true)
      allow(dobj).to receive(:object_type).and_return(Cocina::Models::Vocab.media)
    end
  end

  def exp_xml_object_aa111aa1111
    <<-XML
    <?xml version="1.0"?>
         <contentMetadata type="media" objectId="aa111aa1111">
           <resource type="media" sequence="1" id="aa111aa1111_1">
             <label>Tape 1, Side A</label>
             <file publish="no" preserve="yes" id="aa111aa1111_001_a_pm.wav" shelve="no">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d1eea</checksum>
             </file>
             <file publish="no" preserve="yes" id="aa111aa1111_001_a_sh.wav" shelve="no">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d1eec</checksum>
             </file>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_a_sl.mp3" shelve="yes">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d0eea</checksum>
             </file>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_img_1.jpg" shelve="yes">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d1eea</checksum>
             </file>
           </resource>
           <resource type="file" sequence="2" id="aa111aa1111_2">
             <label>Tape 1, Side B</label>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_b_pm.wav" shelve="yes">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d1eea</checksum>
             </file>
             <file publish="no" preserve="no" id="aa111aa1111_001_b_sh.wav" shelve="no">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d0eeb</checksum>
             </file>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_b_sl.mp3" shelve="yes"/>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_img_2.jpg" shelve="yes">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d4eeb</checksum>
             </file>
           </resource>
           <resource type="text" sequence="3" id="aa111aa1111_3">
             <label>Transcript</label>
             <file publish="yes" preserve="yes" id="aa111aa1111.pdf" shelve="yes"/>
           </resource>
         </contentMetadata>
    XML
  end

  def exp_xml_object_aa111aa1111_with_thumb
    <<-XML
    <?xml version="1.0"?>
         <contentMetadata type="media" objectId="aa111aa1111">
           <resource type="media" sequence="1" id="aa111aa1111_1" thumb="yes">
             <label>Tape 1, Side A</label>
             <file publish="no" preserve="yes" id="aa111aa1111_001_a_pm.wav" shelve="no">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d1eea</checksum>
             </file>
             <file publish="no" preserve="yes" id="aa111aa1111_001_a_sh.wav" shelve="no">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d1eec</checksum>
             </file>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_a_sl.mp3" shelve="yes">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d0eea</checksum>
             </file>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_img_1.jpg" shelve="yes">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d1eea</checksum>
             </file>
           </resource>
           <resource type="file" sequence="2" id="aa111aa1111_2">
             <label>Tape 1, Side B</label>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_b_pm.wav" shelve="yes">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d1eea</checksum>
             </file>
             <file publish="no" preserve="no" id="aa111aa1111_001_b_sh.wav" shelve="no">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d0eeb</checksum>
             </file>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_b_sl.mp3" shelve="yes"/>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_img_2.jpg" shelve="yes">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d4eeb</checksum>
             </file>
           </resource>
           <resource type="text" sequence="3" id="aa111aa1111_3">
             <label>Transcript</label>
             <file publish="yes" preserve="yes" id="aa111aa1111.pdf" shelve="yes"/>
           </resource>
         </contentMetadata>
    XML
  end

  def exp_xml_object_bb222bb2222
    <<-XML
            <?xml version="1.0"?>
            <contentMetadata objectId="bb222bb2222" type="media">
              <resource sequence="1" id="bb222bb2222_1" type="media">
                <label>Tape 1, Side A</label>
                <file id="bb222bb2222_002_a_pm.wav" preserve="yes" publish="no" shelve="no"/>
                <file id="bb222bb2222_002_a_sh.wav" preserve="yes" publish="no" shelve="no"/>
                <file id="bb222bb2222_002_a_sl.mp3" preserve="yes" publish="yes" shelve="yes"/>
                <file id="bb222bb2222_002_img_1.jpg" preserve="yes" publish="yes" shelve="yes"/>
              </resource>
              <resource sequence="2" id="bb222bb2222_2" type="media">
                <label>Tape 1, Side B</label>
                <file id="bb222bb2222_002_b_pm.wav" preserve="yes" publish="no" shelve="no"/>
                <file id="bb222bb2222_002_b_sh.wav" preserve="no" publish="no" shelve="no"/>
                <file id="bb222bb2222_002_b_sl.mp3" preserve="yes" publish="yes" shelve="yes"/>
                <file id="bb222bb2222_002_img_2.jpg" preserve="yes" publish="yes" shelve="yes"/>
              </resource>
              <resource sequence="3" id="bb222bb2222_3" type="text">
                <label>Transcript</label>
                <file id="bb222bb2222.pdf" preserve="yes" publish="yes" shelve="yes" role="transcription"/>
              </resource>
            </contentMetadata>
    XML
  end

  def exp_xml_image_object_aa111aa1111
    <<-XML
    <?xml version="1.0"?>
         <contentMetadata type="image" objectId="aa111aa1111">
           <resource type="media" sequence="1" id="aa111aa1111_1">
             <label>Tape 1, Side A</label>
             <file publish="no" preserve="yes" id="aa111aa1111_001_a_pm.wav" shelve="no">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d1eea</checksum>
             </file>
             <file publish="no" preserve="yes" id="aa111aa1111_001_a_sh.wav" shelve="no">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d1eec</checksum>
             </file>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_a_sl.mp3" shelve="yes">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d0eea</checksum>
             </file>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_img_1.jpg" shelve="yes">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d1eea</checksum>
             </file>
           </resource>
           <resource type="file" sequence="2" id="aa111aa1111_2">
             <label>Tape 1, Side B</label>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_b_pm.wav" shelve="yes">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d1eea</checksum>
             </file>
             <file publish="no" preserve="no" id="aa111aa1111_001_b_sh.wav" shelve="no">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d0eeb</checksum>
             </file>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_b_sl.mp3" shelve="yes"/>
             <file publish="yes" preserve="yes" id="aa111aa1111_001_img_2.jpg" shelve="yes">
               <checksum type="md5">0e80068efa7b0d749ed5da097f6d4eeb</checksum>
             </file>
           </resource>
           <resource type="text" sequence="3" id="aa111aa1111_3">
             <label>Transcript</label>
             <file publish="yes" preserve="yes" id="aa111aa1111.pdf" shelve="yes"/>
           </resource>
         </contentMetadata>
    XML
  end

  def exp_xml_image_object_bb222bb2222
    <<-XML
            <?xml version="1.0"?>
            <contentMetadata objectId="bb222bb2222" type="image">
              <resource sequence="1" id="bb222bb2222_1" type="media">
                <label>Tape 1, Side A</label>
                <file id="bb222bb2222_002_a_pm.wav" preserve="yes" publish="no" shelve="no"/>
                <file id="bb222bb2222_002_a_sh.wav" preserve="yes" publish="no" shelve="no"/>
                <file id="bb222bb2222_002_a_sl.mp3" preserve="yes" publish="yes" shelve="yes"/>
                <file id="bb222bb2222_002_img_1.jpg" preserve="yes" publish="yes" shelve="yes"/>
              </resource>
              <resource sequence="2" id="bb222bb2222_2" type="media">
                <label>Tape 1, Side B</label>
                <file id="bb222bb2222_002_b_pm.wav" preserve="yes" publish="no" shelve="no"/>
                <file id="bb222bb2222_002_b_sh.wav" preserve="no" publish="no" shelve="no"/>
                <file id="bb222bb2222_002_b_sl.mp3" preserve="yes" publish="yes" shelve="yes"/>
                <file id="bb222bb2222_002_img_2.jpg" preserve="yes" publish="yes" shelve="yes"/>
              </resource>
              <resource sequence="3" id="bb222bb2222_3" type="text">
                <label>Transcript</label>
                <file id="bb222bb2222.pdf" preserve="yes" publish="yes" shelve="yes" role="transcription"/>
              </resource>
            </contentMetadata>
    XML
  end
end
