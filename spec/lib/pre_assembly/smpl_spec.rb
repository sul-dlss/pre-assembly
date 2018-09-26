RSpec.describe PreAssembly::Smpl do
  let(:bundle_dir) { Rails.root.join('spec/test_data/smpl_multimedia') }

  describe 'SMPL content metadata generation and techMetadata generation - no thumb declaration' do
    let(:dobj1) { setup_dobj('aa111aa1111', smpl_manifest) }
    let(:dobj2) { setup_dobj('bb222bb2222', smpl_manifest) }
    let(:smpl_manifest) do
      described_class.new(:csv_filename => 'smpl_manifest.csv', :bundle_dir => bundle_dir, :verbose => false)
    end

    it "generates technicalMetadata for SMPL by combining all existing _techmd.xml files" do
      dobj1.create_technical_metadata
      exp_xml = noko_doc(dobj1.technical_md_xml)
      expect(exp_xml.css('technicalMetadata').size).to eq(1) # one top level node
      expect(exp_xml.css('Mediainfo').size).to eq(2) # two Mediainfo nodes
      counts = exp_xml.css('Count')
      expect(counts.size).to eq(4) # four nodes that have file info
      # look for some specific bits in the files that have been assembled
      expect(counts.map(&:content)).to eq(['279', '217', '280', '218'])
    end

    it "generates content metadata from a SMPL manifest with no thumb columns" do
      dobj1.create_content_metadata
      dobj2.create_content_metadata
      expect(noko_doc(dobj1.content_md_xml)).to be_equivalent_to noko_doc(exp_xml_object_aa111aa1111)
      expect(noko_doc(dobj2.content_md_xml)).to be_equivalent_to noko_doc(exp_xml_object_bb222bb2222)
    end
  end # end no thumb declaration

  describe 'SMPL content metadata generation with thumb declaration' do
    it "generates content metadata from a SMPL manifest with a thumb column set to yes" do
      smpl_manifest = described_class.new(:csv_filename => 'smpl_manifest_with_thumb.csv', :bundle_dir => bundle_dir, :verbose => false)
      dobj1 = setup_dobj('aa111aa1111', smpl_manifest)
      dobj2 = setup_dobj('bb222bb2222', smpl_manifest)
      dobj1.create_content_metadata
      dobj2.create_content_metadata
      expect(noko_doc(dobj1.content_md_xml)).to be_equivalent_to noko_doc(exp_xml_object_aa111aa1111_with_thumb)
      expect(noko_doc(dobj2.content_md_xml)).to be_equivalent_to noko_doc(exp_xml_object_bb222bb2222)
    end

    it "generates content metadata from a SMPL manifest with a thumb column set to true" do
      smpl_manifest = described_class.new(:csv_filename => 'smpl_manifest_with_thumb_true.csv', :bundle_dir => bundle_dir, :verbose => false)
      dobj1 = setup_dobj('aa111aa1111', smpl_manifest)
      dobj2 = setup_dobj('bb222bb2222', smpl_manifest)
      dobj1.create_content_metadata
      dobj2.create_content_metadata
      expect(noko_doc(dobj1.content_md_xml)).to be_equivalent_to noko_doc(exp_xml_object_aa111aa1111_with_thumb)
      expect(noko_doc(dobj2.content_md_xml)).to be_equivalent_to noko_doc(exp_xml_object_bb222bb2222)
    end

    it "generates content metadata from a SMPL manifest with no thumbs when the thumb column is set to no" do
      smpl_manifest = described_class.new(:csv_filename => 'smpl_manifest_thumb_no.csv', :bundle_dir => bundle_dir, :verbose => false)
      dobj1 = setup_dobj('aa111aa1111', smpl_manifest)
      dobj2 = setup_dobj('bb222bb2222', smpl_manifest)
      dobj1.create_content_metadata
      dobj2.create_content_metadata
      expect(noko_doc(dobj1.content_md_xml)).to be_equivalent_to noko_doc(exp_xml_object_aa111aa1111)
      expect(noko_doc(dobj2.content_md_xml)).to be_equivalent_to noko_doc(exp_xml_object_bb222bb2222)
    end
  end # end with thumb declaration

  # some helper methods for these tests

  def setup_dobj(druid, smpl_manifest)
    ps = {
      :source_id     => 'SourceIDFoo',
      :project_name  => 'ProjectBar',
      :label         => 'LabelQuux',
      # :publish_attr  => { :publish => 'no', :shelve => 'no', :preserve => 'yes' },
      :project_style => {},
      :bundle_dir    => bundle_dir,
      :smpl_manifest => smpl_manifest,
      :content_md_creation => :smpl_cm_style
    }
    dobj = PreAssembly::DigitalObject.new(ps)
    allow(dobj).to receive(:pid).and_return("druid:#{druid}")
    dobj.container = druid
    dobj.content_md_creation = 'smpl_cm_style'
    dobj
  end

  def exp_xml_object_aa111aa1111
    <<-END
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
    END
  end

  def exp_xml_object_aa111aa1111_with_thumb
    <<-END
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
    END
  end

  def exp_xml_object_bb222bb2222
    <<-END
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
                <file id="bb222bb2222_002_b_pm.wav" preserve="yes" publish="no" shelve="file"/>
                <file id="bb222bb2222_002_b_sh.wav" preserve="no" publish="no" shelve="no"/>
                <file id="bb222bb2222_002_b_sl.mp3" preserve="yes" publish="yes" shelve="yes"/>
                <file id="bb222bb2222_002_img_2.jpg" preserve="yes" publish="yes" shelve="yes"/>
              </resource>
              <resource sequence="3" id="bb222bb2222_3" type="text">
                <label>Transcript</label>
                <file id="bb222bb2222.pdf" preserve="yes" publish="yes" shelve="yes"/>
              </resource>
            </contentMetadata>
    END
  end
end
