require 'assembly'
require 'mini_exiftool'

describe Assembly::Images do
  
  TEST_TIF_INPUT_FILE=File.join(Assembly::PATH_TO_GEM,'spec','test_data','input','test.tif')
  TEST_JP2_INPUT_FILE=File.join(Assembly::PATH_TO_GEM,'spec','test_data','input','test.jp2')
  TEST_JP2_OUTPUT_FILE=File.join(Assembly::PATH_TO_GEM,'spec','test_data','output','test.jp2')
    
  it "should not run if no input file is passed in" do
    Assembly::Images.create_jp2(:input=>'').should be false
  end

  it "should create jp2 when given a tif" do
    File.exists?(TEST_TIF_INPUT_FILE).should be true
    File.exists?(TEST_JP2_OUTPUT_FILE).should be false
    Assembly::Images.create_jp2(:input=>TEST_TIF_INPUT_FILE,:output=>TEST_JP2_OUTPUT_FILE).should be true
    is_jp2?(TEST_JP2_OUTPUT_FILE).should be true
  end
  
  it "should not run if the input file is not a tif" do
    generate_test_jp2(TEST_JP2_INPUT_FILE)
    File.exists?(TEST_JP2_INPUT_FILE).should be true
    Assembly::Images.create_jp2(:input=>TEST_JP2_INPUT_FILE).should be false
  end

  it "should not run if the output file exists and you don't allow overwriting" do
    generate_test_jp2(TEST_JP2_OUTPUT_FILE)
    File.exists?(TEST_TIF_INPUT_FILE).should be true
    File.exists?(TEST_JP2_OUTPUT_FILE).should be true
    Assembly::Images.create_jp2(:input=>TEST_TIF_INPUT_FILE,:output=>TEST_JP2_OUTPUT_FILE).should be false
  end  

  it "should create jp2 of the same filename and in the same location as the input if no output file is specified" do
    File.exists?(TEST_TIF_INPUT_FILE).should be true
    File.exists?(TEST_JP2_INPUT_FILE).should be false
    Assembly::Images.create_jp2(:input=>TEST_TIF_INPUT_FILE).should be true
    is_jp2?(TEST_JP2_INPUT_FILE).should be true   
  end
  
  it "should recreate jp2 if the output file exists and if you allow overwriting" do
    generate_test_jp2(TEST_JP2_OUTPUT_FILE)
    File.exists?(TEST_TIF_INPUT_FILE).should be true
    File.exists?(TEST_JP2_OUTPUT_FILE).should be true
    Assembly::Images.create_jp2(:input=>TEST_TIF_INPUT_FILE,:output=>TEST_JP2_OUTPUT_FILE,:allow_overwrite=>true).should be true
    is_jp2?(TEST_JP2_OUTPUT_FILE).should be true    
  end

  it "should not create jp2 if the output profile is not valid" do
    File.exists?(TEST_TIF_INPUT_FILE).should be true
    File.exists?(TEST_JP2_OUTPUT_FILE).should be false
    Assembly::Images.create_jp2(:input=>TEST_TIF_INPUT_FILE,:output=>TEST_JP2_OUTPUT_FILE,:output_profile=>'junk').should be false
    File.exists?(TEST_JP2_OUTPUT_FILE).should be false
  end
    
  after(:each) do
    # after each test, empty out the output test directory and the test.jp2 in the input directory
    File.delete(TEST_JP2_INPUT_FILE) if File.exists?(TEST_JP2_INPUT_FILE)
    dir_path=File.join(Assembly::PATH_TO_GEM,'spec','test_data','output')
    Dir.foreach(dir_path) {|f| fn = File.join(dir_path, f); File.delete(fn) if !File.directory?(fn) && File.basename(fn)!='empty.txt'}
  end

  # generate a sample jp2 file
  def generate_test_jp2(file)
    system("convert -size 100x100 xc:white #{file}")
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