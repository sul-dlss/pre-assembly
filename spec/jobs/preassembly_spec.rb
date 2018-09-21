RSpec.describe PreassemblyJob, type: :job do
  describe "#perform_later" do

    # TODO: replace with useful tests; this is testing vanilla ActiveJob functionality
    it 'enqueues job' do
      ActiveJob::Base.queue_adapter = :test
      expect {
        described_class.perform_later
      }.to have_enqueued_job(PreassemblyJob)
    end
  end
end
