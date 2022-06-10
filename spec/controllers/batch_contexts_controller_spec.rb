# frozen_string_literal: true

RSpec.describe BatchContextsController, type: :controller do
  let(:params) do
    {
      batch_context:
        {
          project_name: 'Multimedia',
          content_structure: 'simple_image',
          content_metadata_creation: 'default',
          bundle_dir: 'spec/test_data/multimedia',
          job_runs_attributes: { '0' => { job_type: 'preassembly' } }
        }
    }
  end

  context 'users not persisted in db' do
    it 'blocks unauthenticated access' do
      get :new
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'users persisted in db' do
    before { sign_in(create(:user)) }

    it 'has current_user' do
      expect(controller.current_user).not_to be_nil
    end

    describe '#new' do
      it 'renders the new template' do
        get :new
        expect(response).to render_template('new')
        expect(response).to have_http_status(:ok)
      end
    end

    describe '#index' do
      it 'renders index' do
        get :index
        expect(response).to render_template('index')
        expect(response).to have_http_status(:ok)
      end
    end

    describe '#create' do
      context 'Valid Parameters' do
        let(:output_dir) { "#{Settings.job_output_parent_dir}/#{subject.current_user.email}/Multimedia" }

        before { Dir.delete(output_dir) if Dir.exist?(output_dir) }

        it 'passes newly created object' do
          post :create, params: params
          expect(assigns(:batch_context)).to be_a(BatchContext).and be_persisted
          expect(response).to have_http_status(:see_other) # HTTP code for redirect
          expect(response).to redirect_to(job_runs_path)
          expect(flash[:success]).to start_with('Success! Your job is queued.')
        end

        it 'has the correct attributes' do
          post :create, params: params
          bc = assigns(:batch_context)
          expect(bc.project_name).to eq 'Multimedia'
          expect(bc.content_structure).to eq 'simple_image'
          expect(bc.content_metadata_creation).to eq 'default'
          expect(bc.bundle_dir).to eq 'spec/test_data/multimedia'
        end

        it 'persists the first JobRun, rejects dups' do
          expect { post :create, params: params }.to change(JobRun, :count).by(1)
          expect { post :create, params: params }.not_to change(BatchContext, :count)
          Dir.delete(output_dir) if Dir.exist?(output_dir) # even if the directory is missing, cannot reuse user & project_name
          expect { post :create, params: params }.to raise_error(ActiveRecord::RecordNotUnique)
        end
      end

      context 'Invalid Parameters' do
        let(:bc_params) { { project_name: '', content_structure: '', content_metadata_creation: '', bundle_dir: '' } }

        it 'do not create objects' do
          params[:batch_context][:project_name] = nil
          expect { post :create, params: params }.not_to change(BatchContext, :count)
          expect { post :create, params: { batch_context: bc_params } }.not_to change(BatchContext, :count)
          bc_params[:project_name] = "SMPL's folly"
          expect { post :create, params: { batch_context: bc_params } }.not_to change(BatchContext, :count)
        end
      end
    end
  end
end
