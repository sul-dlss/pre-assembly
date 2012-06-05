module PreAssembly

  class ObjectFile

    attr_accessor(
      :path,
      :relative_path,
      :checksum,
      :exclude_from_content
    )

    def initialize(params = {})
      @path                 = params[:path]
      @relative_path        = params[:relative_path]
      @checksum             = params[:checksum]
      @exclude_from_content = params[:exclude_from_content]
      @ao_file              = nil
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
    
    def jp2able?
      assembly_object_file.jp2able?      
    end
    
    def mimetype
      assembly_object_file.mimetype          
    end
      
    def <=>(other)
      @relative_path <=> other.relative_path
    end

  end

end
