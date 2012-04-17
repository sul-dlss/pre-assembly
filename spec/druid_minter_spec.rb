describe PreAssembly::DruidMinter do

  before(:all) do
    @exp = String.new PreAssembly::DruidMinter.current
  end

  it "can exercise next()" do
    5.times do
      v = PreAssembly::DruidMinter.next
      # v.should == @exp
    end
  end

end
