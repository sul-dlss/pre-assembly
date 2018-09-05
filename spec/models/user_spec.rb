RSpec.describe User, type: :model do

  context "validation" do
    subject(:user) { User.new(sunet_id: "jdoe") }

    it "is not valid unless it has all required attributes" do
      expect(User.new).not_to be_valid
      expect(user).to be_valid
    end

    it { is_expected.to validate_uniqueness_of(:sunet_id) }
    it { is_expected.to validate_presence_of(:sunet_id) }
    
    describe 'enforces unique constraint on sunet_id' do
      let(:required_attributes) do
        { sunet_id: "tempdoe" }
      end

      before { described_class.create!(required_attributes) }

      it 'at model level' do
        expect { described_class.create!(required_attributes) }.to raise_error(ActiveRecord::RecordInvalid)
      end
      it 'at db level' do
        dup_user = described_class.new(sunet_id: "tempdoe")
        expect { dup_user.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end
end
