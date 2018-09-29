RSpec.describe 'bundle_contexts/show.html.erb', type: :view do
  let(:bc) { create(:bundle_context) }

  it 'diplays BundleContext info' do
    assign(:bundle_context, bc)
    render
    expect(rendered).to include("<dd class=\"col-sm-9\">#{bc.project_name}</dd>")
    expect(rendered).to include('<i class="far fa-times-circle"></i>') # icon for symlink="false"
  end
end
