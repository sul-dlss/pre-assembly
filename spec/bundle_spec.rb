require 'assembly'

describe Assembly::Bundle do

  before(:each) do
    @ps = {
      :bundle_dir      => 'spec/test_data/bundle_input',
      :manifest        => 'manifest.csv',
      :copy_to_staging => false,
    }
    @b = Assembly::Bundle.new @ps
  end

  it "can be initialized" do
    @b.should be_kind_of Assembly::Bundle
  end

  it "can set the full path to the bundle directory" do
    @b.full_path_in_bundle_dir('foo.txt').should be_kind_of String
  end

  it "gets the correct stager (copier or mover)" do
    @b.copy_to_staging = true
    stager = @b.get_stager
    stager.should equal @b.stagers[:copy]

    @b.copy_to_staging = false
    stager = @b.get_stager
    stager.should equal @b.stagers[:move]
  end

end
