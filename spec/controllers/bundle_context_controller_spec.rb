require 'rails_helper'

RSpec.describe BundleContextController, type: :controller do

  context 'GET index' do
    it "renders the index template" do
      get :index
      expect(response).to render_template("index")
    end
    it "is successful" do
      get :index
      expect(response.status).to eq(200)
    end
  end

  context "POST create" do
    it "renders the create template" do
      post :create
      expect(response).to render_template("create")
    end
    it "is successful" do
      post :create
      expect(response.status).to eq(200)
    end
  end

end
