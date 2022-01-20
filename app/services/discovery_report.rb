# frozen_string_literal: true

# Previously a single untested 200-line method from ./lib/pre_assembly/reporting.rb
# Takes a Batch, enumerates report data via #each_row
class DiscoveryReport
  attr_reader :batch, :start_time, :summary

  delegate :bundle_dir, :content_md_creation, :manifest, :project_style, :using_file_manifest, to: :batch
  delegate :object_filenames_unique?, to: :batch

  # @param [PreAssembly::Batch] batch
  def initialize(batch)
    raise ArgumentError unless batch.is_a?(PreAssembly::Batch)
    @start_time = Time.now
    @batch = batch
    @summary = { objects_with_error: 0, mimetypes: Hash.new(0), start_time: start_time.to_s, total_size: 0 }
  end

  # @return [Enumerable<Hash<Symbol => Object>>]
  # @yield [Hash<Symbol => Object>] data structure about a DigitalObject
  def each_row
    return enum_for(:each_row) unless block_given?
    batch.objects_to_process.each do |dobj|
      row = process_dobj(dobj)
      summary[:total_size] += row.counts[:total_size]
      summary[:objects_with_error] += 1 unless row.errors.empty?
      row.counts[:mimetypes].each { |k, v| summary[:mimetypes][k] += v }
      # log the output to a running progress file
      File.open(batch.batch_context.progress_log_file, 'a') { |f| f.puts log_progress_info(dobj).to_yaml }
      yield row
    end
  end

  # return [Hash] progress info that will be logged as json in a running log file
  def log_progress_info(dobj)
    {
      pid: dobj.pid,
      timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S')
    }
  end

  # @return [String] output_path to store report results, generate a different string each time
  def output_path
    Dir::Tmpname.create(["#{self.class.name.underscore}_", '.json'], batch.batch_context.output_dir) { |path| path }
  end

  # @param [PreAssembly::DigitalObject]
  # @return [Hash<Symbol => Object>]
  def process_dobj(dobj)
    ObjectFileValidator.new(object: dobj, batch: batch).validate
  end

  # @return [Boolean]
  def using_file_manifest?
    using_file_manifest && File.exist?(File.join(bundle_dir, batch.batch_context.file_manifest))
  end

  # @return [PreAssembly::FileManifest]
  def file_manifest
    @file_manifest ||= PreAssembly::FileManifest.new(csv_filename: batch.batch_context.file_manifest, bundle_dir: bundle_dir)
  end

  # By using jbuilder on an enumerator, we reduce memory footprint (vs. to_a)
  # @return [Jbuilder] call obj.to_builder.target! for the JSON string
  def to_builder
    Jbuilder.new do |json|
      json.rows { json.array!(each_row) }
      json.summary summary
    end
  end
end
