RSpec.describe BundleContextsController, type: :controller do
  let(:params) do
    {
      bundle_context:
        {
          project_name: 'Smoke Test',
          content_structure: 'simple_image',
          content_metadata_creation: 'default',
          bundle_dir: 'spec/test_data/smpl_multimedia',
          job_runs_attributes: { "0" =>{ job_type: "preassembly" }}
        }
    }
  end

  context 'users not persisted in db' do
    it 'blocks unauthenticated access' do
      get :index
      expect(response).to have_http_status(401)
    end
  end


  context 'users persisted in db' do

    before { sign_in(User.create(sunet_id: 'foo')) }

    it "should have current_user" do
      expect(subject.current_user).to_not eq(nil)
    end

    context 'GET index' do
      it "renders the index template" do
        get :index
        expect(response).to render_template("index")
        expect(response).to have_http_status(200)
      end
    end

    context "POST create" do
      context "Valid Parameters" do
        before do
          dir = "#{Settings.job_output_parent_dir}/#{subject.current_user.sunet_id}/spec/test_data/smpl_multimedia"
          Dir.delete(dir) if Dir.exist?(dir)
          post :create, params: params
        end

        it 'passes newly created object' do
          expect(assigns(:bundle_context)).to be_a(BundleContext).and be_persisted
          expect(response).to have_http_status(200)
          expect(response).to render_template("create")
        end
        it 'has the correct attributes' do
          bc = assigns(:bundle_context)
          expect(bc.project_name).to eq 'Smoke Test'
          expect(bc.content_structure).to eq "simple_image"
          expect(bc.content_metadata_creation).to eq "default"
          expect(bc.bundle_dir).to eq "spec/test_data/smpl_multimedia"
        end
        it "persists the JobRun" do
          expect { post :create, params: params }.to change(JobRun, :count).by(1)
        end

        it "fails if job_type is nil" do
          params[:bundle_context].merge!(job_runs_attributes: {"0" => { job_type: "" }})
          expect { post :create, params: params }.not_to change(JobRun, :count)
        end
      end

      context "Invalid Parameters" do
        it 'do not create objects' do
          params[:bundle_context].merge!(project_name: nil)
          expect { post :create, params: params }.not_to change(BundleContext, :count)
          expect { post :create, params: { bundle_context: {
            project_name: '',
            content_structure: '',
            content_metadata_creation: '',
            bundle_dir: ''
          }}}.not_to change(BundleContext, :count)
        end
      end
    end
  end
end
