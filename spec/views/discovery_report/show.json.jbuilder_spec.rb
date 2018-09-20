RSpec.describe 'discovery_report/show.json.jbuilder' do
  let(:bundle) { bundle_setup(:flat_dir_images) }
  subject(:report) { DiscoveryReport.new(bundle) }

  before do
    report.bundle.digital_objects.each { |dobj| allow(dobj).to receive(:pid).and_return('kk203bw3276') }
    allow(report).to receive(:registration_check).and_return({}) # pretend everything is in Dor
  end

  it 'renders the wrapper and a row per DigitalObject' do
    assign(:discovery_report, report)
    render
    json = JSON.parse(rendered)
    expect(json).to match a_hash_including(
      'rows' => Array,
      'summary' => a_hash_including('start_time')
    )
  end
end
