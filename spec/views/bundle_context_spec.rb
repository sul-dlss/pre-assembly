# frozen_string_literal: true

RSpec.describe 'batch_contexts/new' do
  context 'Displays the Batch Context Form' do
    it 'displays the form correctly' do
      assign(:batch_context, BatchContext.new)
      # Should render the test page
      render
      expect(rendered).to match(/Project/)
    end
  end

  context 'Displays errors in Batch Context Form'
  it 'displays error message when missing project name' do
    bc = build(:batch_context, project_name: nil).tap(&:valid?)
    assign(:batch_context, bc)
    render
    expect(render).to match(/Project name can&#39;t be blank/)
  end

  it 'displays error message when missing staging_location' do
    bc = build(:batch_context, staging_location: nil).tap(&:valid?)
    assign(:batch_context, bc)
    render
    expect(render).to match(/Staging location can&#39;t be blank/)
  end

  it 'displays error message for non-existent staging location' do
    bc = build(:batch_context, staging_location: 'bad path').tap(&:valid?)
    assign(:batch_context, bc)
    render
    expect(render).to match(/Staging location &#39;bad path&#39; not found./)
  end
end
