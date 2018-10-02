RSpec.describe JobRunsController, type: :controller do
  let(:bc) { create(:bundle_context_with_deleted_output_dir) }

  before { sign_in(create(:user)) }

  describe '#create' do
    context 'with good params' do
      it 'creates JobRun and redirects to index with success flash' do
        expect { post :create, params: { job_run: { bundle_context_id: bc.id } } }
          .to change(JobRun, :count).by(1)
        expect(response).to redirect_to(job_runs_path)
        expect(flash[:success]).to start_with('Success! Your job is queued.')
        expect(bc.job_runs.reload.first.job_type).to eq('discovery_report') # the default
      end
      it 'creates JobRun with correct job_type' do
        post :create, params: { job_run: { bundle_context_id: bc.id, job_type: 'preassembly' } }
        expect(bc.job_runs.reload.first.job_type).to eq('preassembly')
      end
    end

    context 'with bad params' do
      it 'raises' do
        expect { post :create, params: { job_run: { job_type: 'preassembly' } } }
          .to raise_error(ActionController::ParameterMissing)
        expect { post :create, params: { job_run: {} } }.to raise_error(ActionController::ParameterMissing)
      end
      it 'redirects to index with error flash' do
        post :create, params: { job_run: { bundle_context_id: 999 } }
        expect(response).to redirect_to(job_runs_path)
        expect(flash[:error]).not_to be_nil
      end
    end
  end

  describe '#show' do
    it 'returns http success' do
      allow(JobRun).to receive(:find).with('123').and_return(instance_double(JobRun))
      get :show, params: { id: 123 }
      expect(response).to have_http_status(:success)
    end

    it 'requires ID param' do
      expect { get :show }.to raise_error(ActionController::UrlGenerationError)
    end
  end

  describe '#index' do
    it 'returns http success for html view' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'successfully returns json' do
      get :index, format: 'json'
      expect(response).to have_http_status(:success)
      expect(response.header).to include('Content-Type' => 'application/json; charset=utf-8')
    end
  end

  describe '#download' do
    it 'before job is complete, renders page with flash' do
      allow(JobRun).to receive(:find).with('123').and_return(instance_double(JobRun, output_location: nil))
      get :download, params: { id: 123 }
      expect(flash[:warning]).to eq('Job is not complete. Please check back later.')
    end
    it 'when job is complete, returns file attachment' do
      job_run_double = instance_double(JobRun, output_location: 'spec/test_data/input/mock_progress_log.yaml')
      allow(JobRun).to receive(:find).with('123').and_return(job_run_double)
      get :download, params: { id: 123 }
      expect(response).to have_http_status(:success)
      expect(response.header).to include(
        'Content-Type' => 'application/x-yaml',
        'Content-Disposition' => 'attachment; filename="mock_progress_log.yaml"'
      )
      expect(flash[:warning]).to be_nil
    end
    it 'requires ID param' do
      expect { get :download }.to raise_error(ActionController::UrlGenerationError)
    end
  end
end
