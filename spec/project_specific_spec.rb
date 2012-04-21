describe PreAssembly::DigitalObject do

  before(:each) do
    @ps = {
      :apo_druid_id  => 'qq333xx4444',
      :set_druid_id  => 'mm111nn2222',
      :source_id     => 'SourceIDFoo',
      :project_name  => 'ProjectBar',
      :label         => 'LabelQuux',
      :publish_attr  => { :publish => 'no', :shelve => 'no', :preserve => 'yes' },
      :project_style => {},
      :bundle_dir    => 'spec/test_data/bundle_input_e',
    }
    @dobj         = PreAssembly::DigitalObject.new @ps
    @dru          = 'aa111aa1111'
    @pid          = "druid:#{@dru}"
    @druid        = Druid.new @pid
    @tmp_dir_args = [nil, 'tmp']
  end


  ####################

  describe "SMPL specific methods in project_specific module" do

    it "should convert SMPL content metadata into valid base content metadata" do
      @dobj.druid = @druid
      @dobj.create_content_metadata_xml_smpl
      @exp_xml = <<-END.gsub(/^ {8}/, '')
        <?xml version="1.0"?>
        <contentMetadata objectId="ab123cd4567">
          <resource sequence="1" id="ab123cd4567_1">
            <label>Item 1</label>
            <file preserve="yes" publish="no" shelve="no" id="image_1.tif">
              <provider_checksum type="md5">1111</provider_checksum>
            </file>
          </resource>
          <resource sequence="2" id="ab123cd4567_2">
            <label>Item 2</label>
            <file preserve="yes" publish="no" shelve="no" id="image_2.tif">
              <provider_checksum type="md5">2222</provider_checksum>
            </file>
          </resource>
        </contentMetadata>
      END
      @exp_xml = noko_doc @exp_xml
    end

  end
  
end
