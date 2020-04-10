# frozen_string_literal: true

# Previously a single untested 200-line method from ./lib/pre_assembly/reporting.rb
# Takes a Batch, enumerates report data via #each_row
class DiscoveryReport
  attr_reader :batch, :start_time, :summary

  delegate :bundle_dir, :content_md_creation, :manifest, :project_style, to: :batch
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
      yield row
    end
  end

  # @return [String] a different string each time
  def output_path
    Dir::Tmpname.create([self.class.name.underscore + '_', '.json'], batch.batch_context.output_dir) { |path| path }
  end

  # @param [PreAssembly::DigitalObject]
  # @return [Hash<Symbol => Object>]
  def process_dobj(dobj)
    ObjectFileValidator.new(object: dobj, batch: batch).validate
  end

  # @return [Boolean]
  def using_media_manifest?
    content_md_creation == 'media_cm_style' && File.exist?(File.join(bundle_dir, batch.batch_context.media_manifest))
  end

  # @return [PreAssembly::Media]
  def media
    @media ||= PreAssembly::Media.new(csv_filename: batch.batch_context.media_manifest, bundle_dir: bundle_dir)
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
