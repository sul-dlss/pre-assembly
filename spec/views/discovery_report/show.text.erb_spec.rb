RSpec.describe 'discovery_report/show.text.erb' do
  let(:bundle) { bundle_setup(:proj_revs) }
  subject(:report) { DiscoveryReport.new(bundle) }

  before do
    allow_any_instance_of(BundleContextTemporary).to receive(:validate_usage) # replace w/ AR validation
    report.bundle.digital_objects.each { |dobj| allow(dobj).to receive(:pid).and_return('kk203bw3276') }
    allow(report).to receive(:registration_check).and_return({}) # pretend everything is in Dor
  end

  it 'renders the wrapper and a row per DigitalObject' do
    assign(:discovery_report, report)
    render
    expect(rendered).to match(/Discovery Report/)
    expect(rendered).to match(/^Example row output\nExample row output\nExample row output\n[^E]/) # 3 rows
  end
end
