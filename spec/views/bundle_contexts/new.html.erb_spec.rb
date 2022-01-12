# frozen_string_literal: true

RSpec.describe 'batch_contexts/new.html.erb', type: :view do
  let(:job_runs) { create_list(:job_run, 2) }

  it 'displays a list of job_runs in side panel' do
    assign(:batch_context, BatchContext.new)
    assign(:job_runs, job_runs)
    render template: 'batch_contexts/new'
    expect(rendered).to include('<tbody id="job-history-table">') # the element we will render into
    expect(rendered).to include('<script type="text/x-tmpl" id="tmpl-job-history-table">') # the JS template that will be used
  end
end
