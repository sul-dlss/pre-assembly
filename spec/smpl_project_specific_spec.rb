describe PreAssembly::DigitalObject do

  before(:each) do
    @bundle_dir=File.join(PRE_ASSEMBLY_ROOT,'spec/test_data/bundle_input_e')
    @smpl_manifest=PreAssembly::Smpl.new(:csv_filename=>'smpl_manifest.csv',:bundle_dir=>@bundle_dir,:verbose=>false)
    @ps = {
      :apo_druid_id  => 'qq333xx4444',
      :set_druid_id  => 'mm111nn2222',
      :source_id     => 'SourceIDFoo',
      :project_name  => 'ProjectBar',
      :label         => 'LabelQuux',
      :publish_attr  => { :publish => 'no', :shelve => 'no', :preserve => 'yes' },
      :project_style => {},
      :bundle_dir    => @bundle_dir,
      :smpl_manifest => @smpl_manifest,
      :content_md_creation => {:style=>:smpl}
    }
    @dobj         = PreAssembly::DigitalObject.new @ps
    @dru          = 'aa111aa1111'
    @pid          = "druid:#{@dru}"
    @druid        = DruidTools::Druid.new @pid
    @tmp_dir_args = [nil, 'tmp']
    @dobj.druid = @druid
    @dobj.pid = @pid
    @dobj.container = @dru    
    @dobj.content_md_creation[:style]='smpl'
  end
  
  ####################
  describe "SMPL specific technical metadata generation" do

    it "should generate technicalMetadata for SMPL by combining all existing _techmd.xml files" do
      
      @dobj.create_technical_metadata
      exp_xml = noko_doc(@dobj.technical_md_xml)
      exp_xml.css('technicalMetadata').size.should == 1 # one top level node
      exp_xml.css('Mediainfo').size.should == 2 # two Mediainfo nodes
      exp_xml.css('Count').size.should == 4 # four nodes that have file info
      exp_xml.css('Count')[0].content.should == '279' # look for some specific bits in the files that have been assembled
      exp_xml.css('Count')[1].content.should == '217'
      exp_xml.css('Count')[2].content.should == '280'
      exp_xml.css('Count')[3].content.should == '218'
    end
  
  end
  
  describe "SMPL specific methods in project_specific module" do

    it "should convert SMPL content metadata into valid base content metadata" do

      exp_xml = <<-END.gsub(/^ {8}/, '')
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
      @dobj.create_content_metadata      
      noko_doc(@dobj.content_md_xml).should be_equivalent_to noko_doc(exp_xml)
    end

  end
  
end
