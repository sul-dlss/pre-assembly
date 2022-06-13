# frozen_string_literal: true

# Takes a Batch, enumerates report data via #each_row
# To use:
#   report = DiscoveryReport.new(batch_context.batch)
#   report.to_builder.target!  # generates the report as a JSON string
class DiscoveryReport
  attr_reader :batch, :summary
  attr_accessor :error_message, :objects_had_errors

  delegate :bundle_dir, :content_md_creation, :manifest, :project_style, :using_file_manifest, to: :batch
  delegate :object_filenames_unique?, to: :batch

  # @param [PreAssembly::Batch] batch
  def initialize(batch)
    raise ArgumentError unless batch.is_a?(PreAssembly::Batch)

    @batch = batch
    @summary = { objects_with_error: 0, mimetypes: Hash.new(0), start_time: Time.now.utc.to_s, total_size: 0 }
  end

  # this is where we do the work -- by calling process_dobj on each object in the batch
  # @return [Enumerable<Hash<Symbol => Object>>]
  # @yield [Hash<Symbol => Object>] data structure about a DigitalObject
  # rubocop:disable Metrics/AbcSize
  def each_row
    return enum_for(:each_row) unless block_given?

    batch.un_pre_assembled_objects.each do |dobj|
      row = process_dobj(dobj)
      summary[:total_size] += row.counts[:total_size]
      if row.errors.empty?
        status = 'success'
      else
        summary[:objects_with_error] += 1
        status = 'error'
      end
      row.counts[:mimetypes].each { |k, v| summary[:mimetypes][k] += v }
      # log the output to a running progress file
      File.open(batch.batch_context.progress_log_file, 'a') { |f| f.puts log_progress_info(dobj, status).to_yaml }
      yield row
    end
  end
  # rubocop:enable Metrics/AbcSize

  # return [Hash] progress info that will be logged as json in a running log file
  def log_progress_info(dobj, status)
    {
      status: status,
      discovery_finished: true,
      pid: dobj.pid,
      timestamp: Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
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
  # @return [Jbuilder] (caller needs obj.to_builder.target! for the JSON string)
  def to_builder
    json_report = Jbuilder.new do |json|
      json.rows { json.array!(each_row) }
      json.summary summary.merge(end_time: Time.now.utc.to_s)
    end
    @objects_had_errors = (summary[:objects_with_error] > 0) # indicate if any objects generated errors
    @error_message = "#{summary[:objects_with_error]} objects had errors in the discovery report" if objects_had_errors
    json_report
  end
end
