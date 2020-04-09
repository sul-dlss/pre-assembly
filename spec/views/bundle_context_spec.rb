# frozen_string_literal: true

RSpec.describe 'batch_contexts/new' do
  context 'Displays the Bundle Context Form' do
    it 'displays the form correctly' do
      assign(:batch_context, BatchContext.new)
      # Should render the test page
      render
      expect(rendered).to match(/Project/)
    end
  end

  context 'Displays errors in Bundle Context Form'
  it 'displays error message when missing project name' do
    bc = build(:batch_context, project_name: nil).tap(&:valid?)
    assign(:batch_context, bc)
    render
    expect(render).to match(/Project name can&#39;t be blank/)
  end
  it 'displays error message when missing bundle_dir' do
    bc = build(:batch_context, bundle_dir: nil).tap(&:valid?)
    assign(:batch_context, bc)
    render
    expect(render).to match(/Bundle dir can&#39;t be blank/)
  end
  it 'displays error message for non-existent bundle directory' do
    bc = build(:batch_context, bundle_dir: 'bad path').tap(&:valid?)
    assign(:batch_context, bc)
    render
    expect(render).to match(/Bundle dir &#39;bad path&#39; not found./)
  end
end
