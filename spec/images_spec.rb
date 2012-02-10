require 'assembly'
require 'mini_exiftool'

describe Assembly::Images do
  
  TEST_INPUT_DIR=File.join(Assembly::PATH_TO_GEM,'spec','test_data','input')
  TEST_OUTPUT_DIR=File.join(Assembly::PATH_TO_GEM,'spec','test_data','output')

  TEST_TIF_INPUT_FILE=File.join(TEST_INPUT_DIR,'test.tif')
  TEST_JP2_INPUT_FILE=File.join(TEST_INPUT_DIR,'test.jp2')
  TEST_JP2_OUTPUT_FILE=File.join(TEST_OUTPUT_DIR,'test.jp2')
  TEST_DRUID="nx288wh8889"
  
  it "should not run if no input file is passed in" do
    Assembly::Images.create_jp2('').should be false
  end

  it "should create jp2 when given a tif" do
    generate_test_image(TEST_TIF_INPUT_FILE)
    File.exists?(TEST_TIF_INPUT_FILE).should be true
    File.exists?(TEST_JP2_OUTPUT_FILE).should be false
    Assembly::Images.create_jp2(TEST_TIF_INPUT_FILE,:output=>TEST_JP2_OUTPUT_FILE).should be true
    is_jp2?(TEST_JP2_OUTPUT_FILE).should be true
  end
  
  it "should not run if the input file is not a tif" do
    generate_test_image(TEST_JP2_INPUT_FILE)
    File.exists?(TEST_JP2_INPUT_FILE).should be true
    Assembly::Images.create_jp2(TEST_JP2_INPUT_FILE).should be false
  end

  it "should not run if the output file exists and you don't allow overwriting" do
    generate_test_image(TEST_TIF_INPUT_FILE)
    generate_test_image(TEST_JP2_OUTPUT_FILE)
    File.exists?(TEST_TIF_INPUT_FILE).should be true
    File.exists?(TEST_JP2_OUTPUT_FILE).should be true
    Assembly::Images.create_jp2(TEST_TIF_INPUT_FILE,:output=>TEST_JP2_OUTPUT_FILE).should be false
  end  

  it "should create jp2 of the same filename and in the same location as the input if no output file is specified" do
    generate_test_image(TEST_TIF_INPUT_FILE)
    File.exists?(TEST_TIF_INPUT_FILE).should be true
    File.exists?(TEST_JP2_INPUT_FILE).should be false
    Assembly::Images.create_jp2(TEST_TIF_INPUT_FILE).should be true
    is_jp2?(TEST_JP2_INPUT_FILE).should be true   
  end
  
  it "should recreate jp2 if the output file exists and if you allow overwriting" do
    generate_test_image(TEST_TIF_INPUT_FILE)
    generate_test_image(TEST_JP2_OUTPUT_FILE)
    File.exists?(TEST_TIF_INPUT_FILE).should be true
    File.exists?(TEST_JP2_OUTPUT_FILE).should be true
    Assembly::Images.create_jp2(TEST_TIF_INPUT_FILE,:output=>TEST_JP2_OUTPUT_FILE,:allow_overwrite=>true).should be true
    is_jp2?(TEST_JP2_OUTPUT_FILE).should be true    
  end

  it "should not create jp2 if the output profile is not valid" do
    generate_test_image(TEST_TIF_INPUT_FILE)
    File.exists?(TEST_TIF_INPUT_FILE).should be true
    File.exists?(TEST_JP2_OUTPUT_FILE).should be false
    Assembly::Images.create_jp2(TEST_TIF_INPUT_FILE,:output=>TEST_JP2_OUTPUT_FILE,:output_profile=>'junk').should be false
    File.exists?(TEST_JP2_OUTPUT_FILE).should be false
  end

  it "should generate valid content metadata for a single tif and associated jp2" do
    generate_test_image(TEST_TIF_INPUT_FILE)
    generate_test_image(TEST_JP2_INPUT_FILE)
    result=Assembly::Images.create_content_metadata(TEST_DRUID,[[TEST_TIF_INPUT_FILE,TEST_JP2_INPUT_FILE]],"test label")
    result.class.should be String
    xml=Nokogiri::XML(result)
    xml.errors.size.should be 0
    xml.xpath("//resource").length.should be 1
    xml.xpath("//label").length.should be 1
    xml.xpath("//label")[0].text.should == "test label"    
  end

  it "should generate valid content metadata for two sets of tifs and associated jp2s" do
    generate_test_image(TEST_TIF_INPUT_FILE)
    generate_test_image(TEST_JP2_INPUT_FILE)
    result=Assembly::Images.create_content_metadata(TEST_DRUID,[[TEST_TIF_INPUT_FILE,TEST_JP2_INPUT_FILE],[TEST_TIF_INPUT_FILE,TEST_JP2_INPUT_FILE]],"test label2")
    result.class.should be String
    xml=Nokogiri::XML(result)
    xml.errors.size.should be 0
    xml.xpath("//resource").length.should be 2
    xml.xpath("//label").length.should be 2
    xml.xpath("//label")[0].text.should == "test label2"    
    xml.xpath("//label")[1].text.should == "test label2"    
  end

  after(:each) do
    # after each test, empty out the input and output test directories   
    remove_files(TEST_INPUT_DIR)
    remove_files(TEST_OUTPUT_DIR)
  end

  # generate a sample image file
  private
  def generate_test_image(file)
    system("convert -size 100x100 xc:white #{file}")
  end
  
  def remove_files(dir)  
    Dir.foreach(dir) {|f| fn = File.join(dir, f); File.delete(fn) if !File.directory?(fn) && File.basename(fn)!='empty.txt'} 
  end
  
  # check the existence and mime_type of the supplied file and confirm if it's jp2
  def is_jp2?(file)
    if File.exists?(file) 
      exif=MiniExiftool.new file
      return exif['mimetype'] == 'image/jp2'
    else
      false
    end
  end
  
end