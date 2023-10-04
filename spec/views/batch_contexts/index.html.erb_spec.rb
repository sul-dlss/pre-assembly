# frozen_string_literal: true

RSpec.describe 'batch_contexts/index.html.erb' do
  let!(:batch_contexts) { create_list(:batch_context_with_deleted_output_dir, 2) }
  let!(:batch_context_with_globus) { create(:batch_context_with_deleted_output_dir, :with_globus_destination) }
  let(:globus_url) { "https://app.globus.org/file-manager?&amp;destination_id=endpoint_uuid&amp;destination_path=#{batch_context_with_globus.globus_destination.destination_path}" }

  it 'displays a list of batch_contexts' do
    assign(:batch_contexts, BatchContext.all.page(1))
    render template: 'batch_contexts/index'
    expect(rendered).to include(batch_contexts[0].project_name)
    expect(rendered).to include(batch_contexts[1].project_name)
    expect(rendered).to include(batch_context_with_globus.project_name)
    expect(rendered).to include("<a href=\"#{globus_url}\">globus link</a>")
  end
end
