require 'spec_helper'

describe PreAssembly::Remediation::Item do
  context "basic behavior" do
    it "can be instantiated with a pid" do
      @pid = "druid:cs575bk5522"
      @item = PreAssembly::Remediation::Item.new(@pid)
      @item.pid.should eql(@pid)
    end
  end
  context "logging" do
    before(:each) do
      @pid = "druid:cs575bk5522"
      @item = PreAssembly::Remediation::Item.new(@pid)
      @csv_filename = File.dirname(__FILE__) + "/test_data/logging/csv_log.csv"
      @progress_log_file = File.dirname(__FILE__) + "/test_data/logging/progress_log_file.yml"
    end
    after(:each) do
       # File.delete(@csv_filename)
    end
    it "ensures a log file exists" do
      File.delete(@csv_filename) if File.exist?(@csv_filename)
      File.exist?(@csv_filename).should eql(false)
      @item.ensureLogFile(@csv_filename)
      File.exist?(@csv_filename).should eql(true)
      File.file?(@csv_filename).should eql(true)
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
