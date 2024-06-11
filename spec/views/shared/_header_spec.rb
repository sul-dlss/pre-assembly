# frozen_string_literal: true

RSpec.describe 'shared/_header.erb' do
  before { render template: 'shared/_header' }

  it 'Usage Instructions' do
    expect(rendered).to include('<a class="nav-link text-white" href="https://github.com/sul-dlss/pre-assembly/wiki">Usage instructions</a>')
  end

  it 'All jobs' do
    expect(rendered).to include("<a class=\"nav-link\" href=\"/job_runs\">All jobs</a>\n")
  end

  it 'Start new job' do
    expect(rendered).to include("<a class=\"nav-link\" href=\"/\">Start new job</a>\n")
  end

  it 'All projects' do
    expect(rendered).to include("<a class=\"nav-link\" href=\"/batch_contexts\">All projects</a>\n")
  end
end
