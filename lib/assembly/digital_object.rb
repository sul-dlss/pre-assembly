module Assembly

  class DigitalObject
    include Assembly::Logger

    attr_accessor :source_id, :already_processed, :druid

    def initialize(source_id)
      @source_id         = source_id
      @already_processed = false
      @druid             = ''
      @images            = ['foo.tif', 'bar.tif'].map { |file_name| Image::new(file_name) }
    end

    def register
      log "    - register()"
    end

    def modify_workflow
      log "    - modify_workflow()"
    end

    def process_images
      log "    - process_images()"
      @images.each do |img|
        img.process_image
      end
    end

  end # class DigitalObject

end


