require 'spec_helper'

describe 'test/index.html.erb' do
  it 'displays the form correctly' do
    # Should render the test page
    render
    p rendered
  end
end
