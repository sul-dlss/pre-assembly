RSpec.describe 'job_runs/show.html.erb', type: :view do
  let(:job_run) { create(:job_run) }

  it 'displays a job_run' do
    assign(:job_run, job_run)
    render
    expect(rendered).to include("Discovery report \##{job_run.id}")
    expect(rendered).to include("Output location /path/to/report")
  end
end
