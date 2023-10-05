# frozen_string_literal: true

RSpec.describe 'batch_contexts/index.html.erb' do
  let!(:batch_contexts) { create_list(:batch_context_with_deleted_output_dir, 2) }

  context 'with active globus destination' do
    let!(:batch_context_with_globus) { create(:batch_context_with_deleted_output_dir, :with_globus_destination) }

    it 'displays a list of batch_contexts with a globus link' do
      assign(:batch_contexts, BatchContext.all.page(1))
      render template: 'batch_contexts/index'
      expect(rendered).to include(batch_contexts[0].project_name)
      expect(rendered).to include(batch_contexts[1].project_name)
      expect(rendered).to include(batch_context_with_globus.project_name)
      expect(rendered).to include("<a href=\"#{batch_context_with_globus.globus_destination.url.gsub('&', '&amp;')}\">globus link</a>")
    end
  end

  context 'with no active globus destination' do
    it 'displays a list of batch_contexts without globus link' do
      assign(:batch_contexts, BatchContext.all.page(1))
      render template: 'batch_contexts/index'
      expect(rendered).to include(batch_contexts[0].project_name)
      expect(rendered).to include(batch_contexts[1].project_name)
      expect(rendered).not_to include('globus link')
    end
  end
end
