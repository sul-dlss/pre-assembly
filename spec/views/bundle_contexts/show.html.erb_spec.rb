# frozen_string_literal: true

RSpec.describe 'projects/show.html.erb' do
  let(:project) { create(:project) }

  before { assign(:project, project) }

  it 'diplays Project info' do
    render template: 'projects/show'
    expect(rendered).to include("#{project.project_name} by #{project.user.email}")
    expect(rendered).to include('no')
  end

  it 'has buttons for new Jobs' do
    render template: 'projects/show'
    expect(rendered).to include('<input type="submit" name="commit" value="Run Preassembly"')
    expect(rendered).to include('<input type="submit" name="commit" value="New Discovery Report"')
  end

  it 'does not display job summary if none exist' do
    render template: 'projects/show'
    expect(rendered).not_to include('Jobs summary')
  end

  context 'when job runs exist' do
    let(:project) { create(:project) }

    let!(:job_run) { create(:job_run, project:) }

    it 'displays job summary' do
      render template: 'projects/show'
      expect(rendered).to include('Jobs summary')
      expect(rendered).to include("<a href=\"/job_runs/#{job_run.id}\">#{job_run.id}</a>")
      expect(rendered).to include('<td>Discovery report</td>')
      expect(rendered).to include('<td>Waiting</td>')
    end
  end
end
