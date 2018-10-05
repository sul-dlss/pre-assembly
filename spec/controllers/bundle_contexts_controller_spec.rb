RSpec.describe BundleContextsController, type: :controller do
  let(:params) do
    {
      bundle_context:
        {
          project_name: 'SMPL-multimedia',
          content_structure: 'simple_image',
          content_metadata_creation: 'default',
          bundle_dir: 'spec/test_data/smpl_multimedia',
          job_runs_attributes: { '0' => { job_type: 'preassembly' } }
        }
    }
  end

  context 'users not persisted in db' do
    it 'blocks unauthenticated access' do
      get :new
      expect(response).to have_http_status(401)
    end
  end

  context 'users persisted in db' do
    before { sign_in(create(:user)) }

    it 'has current_user' do
      expect(controller.current_user).not_to be_nil
    end

    context '#new' do
      it 'renders the new template' do
        get :new
        expect(response).to render_template('new')
        expect(response).to have_http_status(200)
      end
    end

    describe '#index' do
      it 'renders index' do
        get :index
        expect(response).to render_template('index')
        expect(response).to have_http_status(200)
      end
    end

    context '#create' do
      context 'Valid Parameters' do
        let(:output_dir) { "#{Settings.job_output_parent_dir}/#{subject.current_user.email}/SMPL-multimedia" }

        before { Dir.delete(output_dir) if Dir.exist?(output_dir) }

        it 'passes newly created object' do
          post :create, params: params
          expect(assigns(:bundle_context)).to be_a(BundleContext).and be_persisted
          expect(response).to have_http_status(302) # HTTP code for found
          expect(response).to redirect_to(job_runs_path)
          expect(flash[:success]).to start_with('Success! Your job is queued.')
        end
        it 'has the correct attributes' do
          post :create, params: params
          bc = assigns(:bundle_context)
          expect(bc.project_name).to eq 'SMPL-multimedia'
          expect(bc.content_structure).to eq 'simple_image'
          expect(bc.content_metadata_creation).to eq 'default'
          expect(bc.bundle_dir).to eq 'spec/test_data/smpl_multimedia'
        end
        it 'persists the first JobRun, rejects dups' do
          expect { post :create, params: params }.to change(JobRun, :count).by(1)
          expect { post :create, params: params }.not_to change(BundleContext, :count)
          Dir.delete(output_dir) if Dir.exist?(output_dir) # even if the directory is missing, cannot reuse user & project_name
          expect { post :create, params: params }.to raise_error(ActiveRecord::RecordNotUnique)
        end
      end

      context 'Invalid Parameters' do
        let(:bc_params) { { project_name: '', content_structure: '', content_metadata_creation: '', bundle_dir: '' } }

        it 'do not create objects' do
          params[:bundle_context][:project_name] = nil
          expect { post :create, params: params }.not_to change(BundleContext, :count)
          expect { post :create, params: { bundle_context: bc_params } }.not_to change(BundleContext, :count)
          bc_params[:project_name] = "SMPL's folly"
          expect { post :create, params: { bundle_context: bc_params } }.not_to change(BundleContext, :count)
        end
      end
    end
  end
end
