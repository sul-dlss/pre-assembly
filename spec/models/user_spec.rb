RSpec.describe User, type: :model do
  subject(:user) { build(:user, sunet_id: 'jdoe') }

  context 'validation' do
    it 'is not valid unless it has all required attributes' do
      expect(described_class.new).not_to be_valid
      expect(user).to be_valid
    end

    it { is_expected.to validate_uniqueness_of(:sunet_id) }
    it { is_expected.to validate_presence_of(:sunet_id) }
    it { is_expected.to have_many(:bundle_contexts) }

    describe 'enforces unique constraint on sunet_id' do
      before { user.save! }

      it 'at model level' do
        expect { described_class.create!(sunet_id: user.sunet_id) }.to raise_error(ActiveRecord::RecordInvalid)
      end
      it 'at db level' do
        expect { user.dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  context 'email address' do
    it "returns the user's email address if the sunet_id is already an address" do
      expect(user.email).to eq('jdoe@stanford.edu')
    end

    it 'returns a stanford.edu email address if the sunet_id is not an email address' do
      expect { user.sunet_id = 'jdoe' }.not_to change(user, :email).from('jdoe@stanford.edu')
    end
  end
end
