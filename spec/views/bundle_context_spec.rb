RSpec.describe 'bundle_contexts/new' do
  context 'Displays the Bundle Context Form' do
    it 'displays the form correctly' do
      assign(:bundle_context, BundleContext.new)
      # Should render the test page
      render
      expect(rendered).to match(/Project/)
    end
  end

  context 'Displays errors in Bundle Context Form'
  it 'displays error message when missing project name' do
    bc = build(:bundle_context, project_name: nil).tap(&:valid?)
    assign(:bundle_context, bc)
    render
    expect(render).to match(/Project name can&#39;t be blank/)
  end
  it 'displays error message when missing bundle_dir' do
    bc = build(:bundle_context, bundle_dir: nil).tap(&:valid?)
    assign(:bundle_context, bc)
    render
    expect(render).to match(/Bundle dir can&#39;t be blank/)
  end
  it 'displays error message for non-existent bundle directory' do
    bc = build(:bundle_context, bundle_dir: 'bad path').tap(&:valid?)
    assign(:bundle_context, bc)
    render
    expect(render).to match(/Bundle dir Bundle directory: bad path not found./)
  end
end
