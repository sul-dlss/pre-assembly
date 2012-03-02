describe "Pre-assembly integration" do

  before(:each) do
    @temp_dir = Dir.mktmpdir 'integ_test_', 'tmp'
    @file_patterns = [
      "#{@temp_dir}/**/*.tif",
      "#{@temp_dir}/**/assembly.yml",
    ]
    @exp_n_files = 3
    @b = Assembly::Bundle.new(
      :bundle_dir          => 'spec/test_data/bundle_input',
      :manifest            => 'manifest.csv',
      :checksums_file      => 'checksums.txt',
      :project_name        => 'REVS',
      :apo_druid_id        => 'druid:qv648vd4392',
      :collection_druid_id => 'druid:nt028fd5773',
      :staging_dir         => @temp_dir,
      :copy_to_staging     => true,
      :cleanup             => true
    )
  end

  it "can run pre_assembly and produce expected files in staging dir" do
    lambda { @b.run_pre_assembly }.should_not raise_error
    @file_patterns.each do |patt|
      fs = Dir[patt].select { |f| File.file? f }
      fs.size.should == @exp_n_files
    end
  end

end
