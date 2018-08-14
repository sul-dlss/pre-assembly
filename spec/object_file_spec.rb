require 'spec_helper'

describe PreAssembly::ObjectFile do
  before(:each) do
    @f = PreAssembly::ObjectFile.new(
      :path => 'spec/test_data/bundle_input_a/image1.tif'
    )
  end

  describe "initialization" do
    it "can initialize an ObjectFile" do
      expect(@f).to be_kind_of PreAssembly::ObjectFile
    end
  end
end
