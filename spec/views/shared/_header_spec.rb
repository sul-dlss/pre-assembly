# frozen_string_literal: true

RSpec.describe 'shared/_header.erb' do
  before { render template: 'shared/_header' }

  it 'Usage Instructions' do
    expect(rendered).to include("<a class=\"nav-link\" href=\"https://github.com/sul-dlss/pre-assembly/wiki\">Usage Instructions</a>\n")
  end

  it 'All Jobs' do
    expect(rendered).to include("<a class=\"nav-link\" href=\"/job_runs\">All Jobs</a>\n")
  end

  it 'Start New Projects' do
    expect(rendered).to include("<a class=\"nav-link\" href=\"/\">Start New Project</a>\n")
  end

  it 'All Projects' do
    expect(rendered).to include("<a class=\"nav-link\" href=\"/batch_contexts\">All Projects</a>\n")
  end
end
