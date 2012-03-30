describe "Pre-assembly integration" do

  before(:each) do
    cmf          = Dor::Config.pre_assembly.cm_file_name
    dmf          = Dor::Config.pre_assembly.dm_file_name
    @temp_dir    = Dir.mktmpdir 'integ_test_', 'tmp'
    @exp_n_files = 3

    @file_patterns = [
      "#{@temp_dir}/**/*.tif",
      "#{@temp_dir}/**/#{cmf}",
      "#{@temp_dir}/**/#{dmf}",
    ]

    @b = PreAssembly::Bundle.new(
      :bundle_dir          => 'spec/test_data/bundle_input',
      :manifest            => 'manifest.csv',
      :checksums_file      => 'checksums.txt',
      :project_name        => 'REVS',
      :apo_druid_id        => 'druid:qv648vd4392',
      :set_druid_id        => 'druid:yt502zj0924',
      :staging_dir         => @temp_dir,
      :cleanup             => true,
      :uniqify_source_ids  => true
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
