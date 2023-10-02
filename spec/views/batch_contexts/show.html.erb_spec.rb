# frozen_string_literal: true

RSpec.describe 'batch_contexts/show.html.erb' do
  let(:bc) { create(:batch_context_with_deleted_output_dir) }

  before { assign(:batch_context, bc) }

  it 'diplays BatchContext info' do
    render template: 'batch_contexts/show'
    expect(rendered).to include("Project: #{bc.project_name}")
    expect(rendered).to include('no')
  end

  it 'has buttons for new Jobs' do
    render template: 'batch_contexts/show'
    expect(rendered).to include('<input type="submit" name="commit" value="Run Preassembly"')
    expect(rendered).to include('<input type="submit" name="commit" value="New Discovery Report"')
  end

  it 'does not display job summary if none exist' do
    render template: 'batch_contexts/show'
    expect(rendered).not_to include('Jobs summary')
  end

  context 'when job runs exist' do
    let!(:job_run) { create(:job_run, batch_context: bc) }

    it 'displays job summary' do
      render template: 'batch_contexts/show'
      expect(rendered).to include('Jobs summary')
      expect(rendered).to include("<a href=\"/job_runs/#{job_run.id}\">#{job_run.id}</a>")
      expect(rendered).to include('<td>Discovery report</td>')
      expect(rendered).to include('<td>Waiting</td>')
    end
  end
end
