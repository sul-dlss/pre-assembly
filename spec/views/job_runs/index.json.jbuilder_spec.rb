RSpec.describe 'job_runs/index.json.jbuilder' do
  it 'renders a list of job_runs' do
    render
    json = JSON.parse(rendered)
    # expect(json).to match a_hash_including(
    #   'rows' => Array,
    # )
    skip 'gimme factories'
  end
end
