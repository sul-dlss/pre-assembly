RSpec.describe JobRunsController, type: :controller do
  before { sign_in(create(:user)) }

  describe 'GET #show' do
    it 'returns http success' do
      allow(JobRun).to receive(:find).with('123').and_return(instance_double(JobRun))
      get :show, params: { id: 123 }
      expect(response).to have_http_status(:success)
    end

    it 'requires ID param' do
      expect { get :show }.to raise_error(ActionController::UrlGenerationError)
    end
  end

  describe 'GET #index' do
    it 'returns http success for html view' do
      allow(JobRun).to receive(:find).with('123').and_return(instance_double(JobRun))
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'returns http success for json view' do
      allow(JobRun).to receive(:find).with('123').and_return(instance_double(JobRun))
      get :index, format: 'JSON'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET #download' do
    it 'before job is complete, renders page with flash' do
      allow(JobRun).to receive(:find).with('123').and_return(instance_double(JobRun, output_location: nil))
      get :download, params: { id: 123 }
      expect(flash[:notice]).to eq('Job is not complete.  Please check back later.')
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
      expect(flash[:notice]).to be_nil
    end
    it 'requires ID param' do
      expect { get :download }.to raise_error(ActionController::UrlGenerationError)
    end
  end
end
