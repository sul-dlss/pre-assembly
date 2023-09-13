# frozen_string_literal: true

RSpec.describe JobRunsController do
  let(:bc) { create(:batch_context_with_deleted_output_dir) }

  before { sign_in(create(:user)) }

  describe '#create' do
    context 'with good params' do
      it 'creates JobRun and redirects to index with success flash' do
        expect { post :create, params: { job_run: { batch_context_id: bc.id } } }
          .to change(JobRun, :count).by(1)
        expect(response).to redirect_to(job_runs_path)
        expect(flash[:success]).to start_with('Success! Your job is queued.')
        expect(bc.job_runs.reload.first.job_type).to eq('discovery_report') # the default
      end

      it 'creates JobRun with correct job_type' do
        post :create, params: { job_run: { batch_context_id: bc.id, job_type: 'preassembly' } }
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
        post :create, params: { job_run: { batch_context_id: 999 } }
        expect(response).to redirect_to(job_runs_path)
        expect(flash[:error]).not_to be_nil
      end
    end
  end

  describe '#show' do
    let(:job_run) { instance_double(JobRun) }

    before do
      allow(JobRun).to receive(:find).with('123').and_return(job_run)
      allow(job_run).to receive_messages(report_ready?: false, progress_log_file_exists?: false)
    end

    it 'returns http success' do
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
  end

  describe '#download_log' do
    it 'before job is started, renders page with flash' do
      allow(JobRun).to receive(:find).with('123').and_return(instance_double(JobRun, progress_log_file_exists?: false))
      get :download_log, params: { id: 123 }
      expect(flash[:warning]).to eq('Progress log file not available.')
    end

    it 'returns file attachment' do
      job_run_double = instance_double(JobRun, progress_log_file: 'spec/fixtures/input/mock_progress_log.yaml', progress_log_file_exists?: true)
      allow(JobRun).to receive(:find).with('123').and_return(job_run_double)
      get :download_log, params: { id: 123 }
      expect(response).to have_http_status(:success)
      expect(response.header['Content-Type']).to eq 'application/x-yaml'
      expect(response.header['Content-Disposition']).to start_with 'attachment; filename="mock_progress_log.yaml"'
      expect(flash[:warning]).to be_nil
    end

    it 'requires ID param' do
      expect { get :download_log }.to raise_error(ActionController::UrlGenerationError)
    end
  end

  describe '#download_report' do
    it 'before job is complete, renders page with flash' do
      allow(JobRun).to receive(:find).with('123').and_return(instance_double(JobRun, output_location: nil))
      get :download_report, params: { id: 123 }
      expect(flash[:warning]).to eq('Job is not complete. Please check back later.')
    end

    it 'when job is complete, returns file attachment' do
      job_run_double = instance_double(JobRun, output_location: 'spec/fixtures/input/mock_discovery_report.json')
      allow(JobRun).to receive(:find).with('123').and_return(job_run_double)
      get :download_report, params: { id: 123 }
      expect(response).to have_http_status(:success)
      expect(response.header['Content-Type']).to eq 'application/json'
      expect(response.header['Content-Disposition']).to start_with 'attachment; filename="mock_discovery_report.json"'
      expect(flash[:warning]).to be_nil
    end

    it 'requires ID param' do
      expect { get :download_report }.to raise_error(ActionController::UrlGenerationError)
    end
  end

  describe '#discovery_report_summary' do
    it 'before job is started, renders page with flash' do
      allow(JobRun).to receive(:find).with('123').and_return(instance_double(JobRun, report_ready?: false))
      get :discovery_report_summary, params: { id: 123 }
      expect(flash[:warning]).to eq('There is no discovery report. Please check back later.')
    end

    it 'returns http success' do
      job_run_double = instance_double(JobRun, report_ready?: true, output_location: 'spec/fixtures/input/mock_discovery_report.json')
      allow(JobRun).to receive(:find).with('123').and_return(job_run_double)
      get :discovery_report_summary, params: { id: 123 }
      expect(response).to have_http_status(:success)
      expect(flash[:warning]).to be_nil
    end

    it 'requires ID param' do
      expect { get :discovery_report_summary }.to raise_error(ActionController::UrlGenerationError)
    end
  end

  describe '#progress_log' do
    it 'before job is started, renders page with flash' do
      allow(JobRun).to receive(:find).with('123').and_return(instance_double(JobRun, progress_log_file_exists?: false))
      get :progress_log, params: { id: 123 }
      expect(flash[:warning]).to eq('Progress log file not available.')
    end

    it 'returns http success' do
      job_run_double = instance_double(JobRun, progress_log_file: 'spec/fixtures/input/mock_progress_log.yaml', progress_log_file_exists?: true)
      allow(JobRun).to receive(:find).with('123').and_return(job_run_double)
      get :progress_log, params: { id: 123 }
      expect(response).to have_http_status(:success)
      expect(flash[:warning]).to be_nil
    end

    it 'requires ID param' do
      expect { get :progress_log }.to raise_error(ActionController::UrlGenerationError)
    end
  end
end
