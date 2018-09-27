RSpec.describe 'bundle_contexts/new.html.erb', type: :view do
  let!(:job_runs) { create_list(:job_run, 2) }

  it 'displays a list of job_runs in side panel' do
    assign(:bundle_context, BundleContext.new)
    assign(:job_runs, JobRun.all.page(1))
    render
    expect(rendered).to include('<tbody id="job-history-table">') # the element we will render into
    expect(rendered).to include('<script type="text/x-tmpl" id="tmpl-job-history-table">') # the JS template that will be used
  end
end
