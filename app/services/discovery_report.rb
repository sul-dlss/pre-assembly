# frozen_string_literal: true

# Previously a single untested 200-line method from ./lib/pre_assembly/reporting.rb
# Takes a Bundle, enumerates report data via #each_row
class DiscoveryReport
  attr_reader :bundle, :start_time, :summary

  delegate :bundle_dir, :content_md_creation, :manifest, :project_style, to: :bundle
  delegate :object_filenames_unique?, to: :bundle

  # @param [PreAssembly::Bundle] bundle
  def initialize(bundle)
    raise ArgumentError unless bundle.is_a?(PreAssembly::Bundle)
    @start_time = Time.now
    @bundle = bundle
    @summary = { objects_with_error: 0, mimetypes: Hash.new(0), start_time: start_time.to_s, total_size: 0 }
  end

  # @return [Enumerable<Hash<Symbol => Object>>]
  # @yield [Hash<Symbol => Object>] data structure about a DigitalObject
  def each_row
    return enum_for(:each_row) unless block_given?
    bundle.objects_to_process.each do |dobj|
      row = process_dobj(dobj)
      summary[:total_size] += row.counts[:total_size]
      summary[:objects_with_error] += 1 unless row.errors.empty?
      row.counts[:mimetypes].each { |k, v| summary[:mimetypes][k] += v }
      yield row
    end
  end

  # @return [String] a different string each time
  def output_path
    Dir::Tmpname.create([self.class.name.underscore + '_', '.json'], bundle.bundle_context.output_dir) { |path| path }
  end

  # @param [PreAssembly::DigitalObject]
  # @return [Hash<Symbol => Object>]
  def process_dobj(dobj)
    ObjectFileValidator.new(object: dobj, bundle: bundle).validate
  end

  # @return [Boolean]
  def using_media_manifest?
    content_md_creation == 'media_cm_style' && File.exist?(File.join(bundle_dir, bundle.bundle_context.media_manifest))
  end

  # @return [PreAssembly::Media]
  def media
    @media ||= PreAssembly::Media.new(csv_filename: bundle.bundle_context.media_manifest, bundle_dir: bundle_dir)
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
