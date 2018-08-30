RSpec.describe PreAssembly::DruidMinter do
  it "gets a sequence of druids from calls to next()" do
    exp = described_class.current
    3.times { expect(described_class.next).to eq(exp.next!) }
  end

  it "returns unique string objects" do
    o1 = described_class.next
    o2 = described_class.next
    expect(o1.object_id).not_to eq(o2.object_id)
  end
end
