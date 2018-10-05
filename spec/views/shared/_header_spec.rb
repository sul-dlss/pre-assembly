RSpec.describe 'shared/_header.erb' do
  context "should have the right links on the header" do
    before { render }
    it 'Usage Instructions' do
      expect(rendered).to include("<a class=\"nav-link\" href=\"https://github.com/sul-dlss/pre-assembly/wiki\">Usage Instructions</a>\n")
    end
    it 'All Jobs' do
      expect(rendered).to include("<a class=\"nav-link\" href=\"/job_runs\">All Jobs</a>\n")
    end
    it 'Start New Projects' do
      expect(rendered).to include("<a class=\"nav-link\" href=\"/\">Start New Project</a>\n")
    end
    it 'Accessioning' do
      expect(rendered).to include("<h1 class=\"p-4\">Accessioning</h1>\n")
    end
  end
end
