# frozen_string_literal: true

require 'axe-rspec'

RSpec.describe 'Accessibility testing', :js do
  let(:user) { create(:user) }
  let(:user_id) { "#{user.sunet_id}@stanford.edu" }

  before do
    login_as(user, scope: :user)
  end

  it 'validates the home page' do
    visit root_path
    expect(page).to be_accessible
  end

  it 'validates the batch contexts page' do
    visit batch_contexts_path
    expect(page).to be_accessible
  end

  it 'validates the jobs page' do
    visit job_runs_path
    expect(page).to be_accessible
  end

  def be_accessible
    be_axe_clean
  end
end
