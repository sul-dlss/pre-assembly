RSpec.describe User, type: :model do

  context "validation" do
    subject(:user) { User.new(sunet_id: "jdoe@stanford.edu") }

    it "is not valid unless it has all required attributes" do
      expect(User.new).not_to be_valid
      expect(user).to be_valid
    end

    it { is_expected.to validate_uniqueness_of(:sunet_id) }
    it { is_expected.to validate_presence_of(:sunet_id) }
    it { is_expected.to have_many(:bundle_contexts) }

    describe 'enforces unique constraint on sunet_id' do
      let(:required_attributes) do
        { sunet_id: "tempdoe@stanford.edu" }
      end

      before { described_class.create!(required_attributes) }

      it 'at model level' do
        expect { described_class.create!(required_attributes) }.to raise_error(ActiveRecord::RecordInvalid)
      end
      it 'at db level' do
        dup_user = described_class.new(sunet_id: "tempdoe@stanford.edu")
        expect { dup_user.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end
  context "email address" do

    it "returns the user's email address if the sunet_id is already an address" do
      user = User.new(sunet_id: 'jdoe@stanford.edu')
      expect(user.email).to eq('jdoe@stanford.edu')
    end

    it "returns the user's email address if the sunet_id is not an email address" do
      user = User.new(sunet_id: 'jdoe')
      expect(user.email).to eq('jdoe@stanford.edu')
    end
  end
end
