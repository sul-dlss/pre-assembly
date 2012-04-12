module PreAssembly

  class ObjectFile

    include PreAssembly::Logging

    attr_accessor :path, :relative_path, :checksum

    def initialize(params = {})
      @path          = params[:path]
      @relative_path = params[:relative_path]
      @checksum      = params[:checksum]
      @ao_file       = nil
    end

    def assembly_object_file
      @ao_file ||= Assembly::ObjectFile.new @path
    end

    def image?
      assembly_object_file.image?
    end

    def valid_image?
      assembly_object_file.valid_image?
    end

  end

end
