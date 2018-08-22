require 'spec_helper'

describe PreAssembly::Remediation::Item do
  context "basic behavior" do
    it "can be instantiated with a pid" do
      @pid = "druid:cs575bk5522"
      @item = described_class.new(@pid)
      expect(@item.pid).to eql(@pid)
    end
  end

  context "logging" do
    before do
      @pid = "druid:cs575bk5522"
      @item = described_class.new(@pid)
      @log_dir = File.dirname(__FILE__) + "/test_data/logging"
      Dir.mkdir(@log_dir) unless Dir.exist?(@log_dir)
      @csv_filename = @log_dir + "/csv_log.csv"
      @progress_log_file = @log_dir + "/progress_log_file.yml"
    end

    after do
      # File.delete(@csv_filename)
    end

    it "ensures a log file exists" do
      File.delete(@csv_filename) if File.exist?(@csv_filename)
      expect(File.exist?(@csv_filename)).to be(false)
      @item.ensureLogFile(@csv_filename)
      expect(File.exist?(@csv_filename)).to be(true)
      expect(File.file?(@csv_filename)).to be(true)
    end
    it "takes a CSV file for logging" do
      @item.success = "true"
      @item.message = "message"
      @item.log_to_csv(@csv_filename)
    end
    it "logs to a progress file as yml" do
      @item.success = "true"
      @item.message = "message"
      @item.log_to_progress_file(@progress_log_file)
    end
  end
end
