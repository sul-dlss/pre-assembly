# TODO: implement some tests.

describe "Pre-assembly integration" do

  before(:each) do
    @bundle = Assembly::Bundle.new(
      :bundle_dir          => 'spec/test_data/bundle_input',
      :manifest            => 'manifest.csv',
      :checksums_file      => 'checksums.txt',
      :project_name        => 'REVS',
      :apo_druid_id        => 'druid:qv648vd4392',
      :collection_druid_id => 'druid:nt028fd5773',
      :staging_dir         => 'tmp',
      :copy_to_staging     => true,
      :cleanup             => true
    )
  end

  it "can run the assembly process" do
    @bundle.run_assembly

    @bundle.digital_objects.each do |dobj|
      p dobj.druid_tree_dir
    end
  end

end
