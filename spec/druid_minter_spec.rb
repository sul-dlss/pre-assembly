require 'spec_helper'

describe PreAssembly::DruidMinter do

  before(:all) do
    @minter = PreAssembly::DruidMinter
  end

  it "should get a sequence of druids from calls to next()" do
    exp = @minter.current
    3.times { @minter.next.should == exp.next! }
  end

  it "should return unique string objects" do
    o1 = @minter.next
    o2 = @minter.next
    o1.object_id.should_not == o2.object_id
  end

end
