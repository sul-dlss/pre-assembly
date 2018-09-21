RSpec.describe 'job_runs/index.html.erb', type: :view do
  let!(:job_runs) { create_list(:job_run, 2) }

  it 'displays a list of job_runs' do
    assign(:job_runs, JobRun.all.page(1))
    render
    expect(rendered).to include("Job \##{job_runs[0].id}")
    expect(rendered).to include("Job \##{job_runs[1].id}")
  end
end
