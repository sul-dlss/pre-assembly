# frozen_string_literal: true

RSpec.describe 'projects/new' do
  context 'Displays the Batch Context Form' do
    it 'displays the form correctly' do
      assign(:project, Project.new)
      # Should render the test page
      render
      expect(rendered).to match(/Project/)
    end
  end

  context 'Displays errors in Batch Context Form'
  it 'displays error message when missing project name' do
    project = build(:project, project_name: nil).tap(&:valid?)
    assign(:project, project)
    render
    expect(render).to match(/Project name can&#39;t be blank/)
  end

  it 'displays error message when missing staging_location' do
    project = build(:project, staging_location: nil).tap(&:valid?)
    assign(:project, project)
    render
    expect(render).to match(/Staging location can&#39;t be blank/)
  end

  it 'displays error message for non-existent staging location' do
    project = build(:project, staging_location: 'bad path').tap(&:valid?)
    assign(:project, project)
    render
    expect(render).to match(/Staging location &#39;bad path&#39; not found./)
  end
end
