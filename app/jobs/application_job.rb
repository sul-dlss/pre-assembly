# frozen_string_literal: true
require 'ruby-prof'

class ApplicationJob < ActiveJob::Base
  def create_ruby_prof_result_path
    "#{Rails.root}/log/ruby-prof_result_reports/#{self.class}/#{DateTime.now.utc.iso8601}".tap do |dir_name|
      FileUtils.mkdir_p dir_name
    end
  end

  def ruby_prof_measure_mode
    # options: RubyProf::WALL_TIME, RubyProf::PROCESS_TIME, RubyProf::ALLOCATIONS, RubyProf::MEMORY
    RubyProf::MEMORY
  end

  def ruby_prof_printers_to_use
    # options: :flat, :graph, :graph_html, :tree, :call_info, :stack, :dot
    [:flat, :graph, :graph_html, :tree, :call_info, :stack, :dot]
  end

  attr_accessor :ruby_prof_result_path

  around_perform do |job, block|
    job.ruby_prof_result_path = create_ruby_prof_result_path
    RubyProf.measure_mode = ruby_prof_measure_mode
    RubyProf.start
    block.call
  ensure
    profiling_result = RubyProf.stop
    # Marshal.dump(profiling_result)
    RubyProf::MultiPrinter.new(profiling_result, ruby_prof_printers_to_use).print(path: job.ruby_prof_result_path)
    prof_results_msg = "profiling results available at #{job.ruby_prof_result_path}"
    $stdout.puts prof_results_msg
    Rails.logger.info prof_results_msg
  end
end
