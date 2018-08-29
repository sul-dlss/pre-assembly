require 'rails_helper'

describe 'template/index' do
  it 'displays the form correctly' do
    # Should render the test page
    render
    expect(rendered).to match(/Project/)
  end
end
