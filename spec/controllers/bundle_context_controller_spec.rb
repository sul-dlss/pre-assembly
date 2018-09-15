RSpec.describe BundleContextController, type: :controller do
  let(:params) do
    {
      project_name: 'Smoke Test',
      content_structure: 'simple_image',
      content_metadata_creation: 'default',
      bundle_dir: 'spec/test_data/smpl_multimedia'
    }
  end

  before { sign_in(User.create(sunet_id: 'foo')) }

  describe 'GET index' do
    it "renders the index template" do
      get :index
      expect(response).to render_template("index")
      expect(response).to have_http_status(200)
    end
  end

  context "POST create" do
    context "Valid Parameters" do
      before { post :create, params: params }

      it 'passes newly created object' do
        expect(assigns(:bundle_context)).to be_a(BundleContext).and be_persisted
        expect(response).to have_http_status(200)
      end
      it 'has the correct attributes' do
        bc = assigns(:bundle_context)
        expect(bc.project_name).to eq 'Smoke Test'
        expect(bc.content_structure).to eq "simple_image"
        expect(bc.content_metadata_creation).to eq "default"
        expect(bc.bundle_dir).to eq "spec/test_data/smpl_multimedia"
      end
    end

    context "Invalid Parameters" do
      it 'do not create objects' do
        expect { post :create, params: params.merge(project_name: nil) }.not_to change(BundleContext, :count)
        expect { post :create }.not_to change(BundleContext, :count)
      end
    end
  end
end
