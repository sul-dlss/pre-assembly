RSpec.describe 'bundle_contexts/index' do
  context "Displays the Bundle Context Form" do
    it 'displays the form correctly' do
      assign(:bundle_context, BundleContext.new)
      # Should render the test page
      render
      expect(rendered).to match(/Project/)
    end
  end

  context "Displays errors in Bundle Context Form"
  it 'displays error message when missing project name' do
    assign(:bundle_context, BundleContext.create(
                              project_name: nil,
                              content_structure: "simple_image",
                              content_metadata_creation: "default",
                              bundle_dir: "spec/test_data/bundle_input_b"
                            ))
    render
    expect(render).to match(/Project name can&#39;t be blank/)
  end
  it 'displays error message when missing bundle_dir' do
    assign(:bundle_context, BundleContext.create(
                              project_name: "A great project",
                              content_structure: "simple_image",
                              content_metadata_creation: "default",
                              bundle_dir: nil
                            ))
    render
    expect(render).to match(/Bundle dir can&#39;t be blank/)
  end
  it 'displays error message for non-existent bundle directory' do
    assign(:bundle_context, BundleContext.create(
                              project_name: "Another great project",
                              content_structure: "simple_image",
                              content_metadata_creation: "default",
                              bundle_dir: "bad path"
                            ))
    render
    expect(render).to match(/Bundle dir Bundle directory: bad path not found./)
  end
end
