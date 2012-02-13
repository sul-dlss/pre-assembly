module Assembly

  class DigitalObject
    include Assembly::Logger

    attr_accessor :source_id, :already_processed, :druid

    def initialize(source_id)
      @source_id         = source_id
      @already_processed = false
      @druid             = ''
    end

  end # class DigitalObject

end


