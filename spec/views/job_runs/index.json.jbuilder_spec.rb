RSpec.describe 'job_runs/index.json.jbuilder' do
  let!(:job_runs) { create_list(:job_run, 2) }

  it 'renders a list of job_runs' do
    assign(:job_runs, JobRun.all.page(1))
    render
    json = JSON.parse(rendered)
    expect(json.class).to eq Array
    expect(json.size).to eq 2
    expect(json[0]).to match a_hash_including(
      'job_type' => 'discovery_report',
      'output_location' => '/path/to/report'
    )
    expect(json[1]).to match a_hash_including(
      'job_type' => 'discovery_report',
      'output_location' => '/path/to/report'
    )
  end
end
