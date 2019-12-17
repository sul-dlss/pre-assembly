# frozen_string_literal: true

module PreAssembly
  # Looks for *_techmd.xml files in the bundle_dir and concatenates them
  class MediaProjectTechnicalMetadataCreator
    def initialize(pid:, bundle_dir:, container:)
      @pid = pid
      @bundle_dir = bundle_dir
      @container = container
    end

    # find all technical metadata files and append the xml to the combined technicalMetadata
    def create
      build_document do |combined|
        in_bundle_directory do
          tech_files_in_current_directory.each do |filename|
            append_file(combined, filename)
          end
        end
      end
    end

    private

    attr_reader :bundle_dir, :container, :pid

    def container_basename
      File.basename(container)
    end

    def append_file(combined, filename)
      tech_md_xml = Nokogiri::XML(File.open(File.join(bundle_dir, container_basename, filename)))
      combined.root << tech_md_xml.root
    end

    def tech_files_in_current_directory
      Dir.glob('**/*_techmd.xml').sort
    end

    def in_bundle_directory
      current_directory = Dir.pwd
      FileUtils.cd(File.join(bundle_dir, container_basename))
      yield
      FileUtils.cd(current_directory)
    end

    def build_document
      tm = Nokogiri::XML::Document.new
      tm_node = Nokogiri::XML::Node.new('technicalMetadata', tm)
      tm_node['objectId'] = pid
      tm_node['datetime'] = Time.now.utc.strftime('%Y-%m-%d-T%H:%M:%SZ')
      tm << tm_node
      yield tm
      tm.to_xml
    end
  end
end
