RSpec.describe User, type: :model do
  subject(:user) { build(:user, email: 'jdoe@stanford.edu') }

  context 'validation' do
    it 'is not valid unless it has all required attributes' do
      expect(User.new).not_to be_valid
      expect(user).to be_valid
    end

    it { is_expected.to validate_uniqueness_of(:email).ignoring_case_sensitivity }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to have_many(:bundle_contexts) }

    describe 'enforces unique constraint on email' do
      before { user.save! }

      it 'at model level' do
        expect { described_class.create!(email: user.email) }.to raise_error(ActiveRecord::RecordInvalid)
      end
      it 'at db level' do
        expect { user.dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  context 'email address' do
    it "returns the user's email address" do
      expect(user.email).to eq('jdoe@stanford.edu')
    end

    it "returns the user's sunet id" do
      expect(user.sunet_id).to eq('jdoe')
    end
  end
end
