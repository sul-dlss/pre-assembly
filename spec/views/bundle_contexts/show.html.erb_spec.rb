RSpec.describe 'bundle_contexts/show.html.erb', type: :view do
  let(:bc) { create(:bundle_context) }

  before { assign(:bundle_context, bc) }

  it 'diplays BundleContext info' do
    render
    expect(rendered).to include("<a href=\"/bundle_contexts/1\">#{bc.project_name}</a> by #{bc.user.email}")
    expect(rendered).to include('<i class="far fa-times-circle"></i>') # icon for symlink="false"
  end

  it 'has buttons for new Jobs' do
    render
    expect(rendered).to include('<input type="submit" name="commit" value="Run Preassembly"')
    expect(rendered).to include('<input type="submit" name="commit" value="New Discovery Report"')
  end
end
