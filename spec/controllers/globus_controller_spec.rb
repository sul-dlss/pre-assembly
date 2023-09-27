# frozen_string_literal: true

RSpec.describe GlobusController do
  before do
    sign_in(create(:user))
    allow(GlobusClient).to receive(:mkdir).and_return(true)
  end

  describe '#create' do
    context 'with successful GlobusClient call' do
      it 'creates the GlobusDestination and calls GlobusClient' do
        post(:create)
        expect(assigns(:user)).to eq(controller.current_user)
        expect(assigns(:dest)).to be_a(GlobusDestination).and be_persisted
        expect(GlobusClient).to have_received(:mkdir)
        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to have_key('url')
        expect(response.parsed_body).to have_key('location')
      end
    end
  end
end
