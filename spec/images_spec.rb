require 'assembly'
require 'mini_exiftool'

describe Assembly::Images do
  
  it "should not run if no input file is passed in" do
    Assembly::Images.create_jp2(:input=>'').should be false
  end
  
  it "should not run if the input file is not a tif" do
    input_file=File.join(Assembly::PATH_TO_GEM,'spec','test_data','input','test.jp2')
    File.exists?(input_file).should be true
    Assembly::Images.create_jp2(:input=>input_file).should be false
  end

  it "should not run if the output file exists and you don't allow overwriting" do
    input_file=File.join(Assembly::PATH_TO_GEM,'spec','test_data','input','test.tif')
    File.exists?(input_file).should be true
    Assembly::Images.create_jp2(:input=>input_file).should be false
  end  

  it "should recreate jp2 if the output file exists, if you don't supply an alternate filename and if you allow overwriting" do
    input_file=File.join(Assembly::PATH_TO_GEM,'spec','test_data','input','test.tif')
    output_file=File.join(Assembly::PATH_TO_GEM,'spec','test_data','input','test.jp2')
    File.exists?(input_file).should be true
    File.exists?(output_file).should be true
    Assembly::Images.create_jp2(:input=>input_file,:allow_overwrite=>true).should be true
    File.exists?(output_file).should be true    
  end

  it "should not create jp2 if the output profile is not valid" do
    input_file=File.join(Assembly::PATH_TO_GEM,'spec','test_data','input','test.tif')
    output_file=File.join(Assembly::PATH_TO_GEM,'spec','test_data','output','test.jp2')
    File.exists?(input_file).should be true
    File.exists?(output_file).should be false
    Assembly::Images.create_jp2(:input=>input_file,:output=>output_file,:output_profile=>'junk').should be false
    File.exists?(output_file).should be false
  end

  it "should create jp2 if it does not exist" do
    input_file=File.join(Assembly::PATH_TO_GEM,'spec','test_data','input','test.tif')
    output_file=File.join(Assembly::PATH_TO_GEM,'spec','test_data','output','test.jp2')
    File.exists?(input_file).should be true
    File.exists?(output_file).should be false
    Assembly::Images.create_jp2(:input=>input_file,:output=>output_file).should be true
    File.exists?(output_file).should be true
    exif=MiniExiftool.new output_file
    exif['mimetype'].should == 'image/jp2'
  end
  
  after(:each) do
    # after each test, empty out the output test directory
    dir_path=File.join(Assembly::PATH_TO_GEM,'spec','test_data','output')
    Dir.foreach(dir_path) {|f| fn = File.join(dir_path, f); File.delete(fn) if !File.directory?(fn) && File.basename(fn)!='empty.txt'}
  end
  
end