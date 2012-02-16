module Assembly

  class Image
    include Assembly::Logging

    attr_accessor :file_name

    def initialize(file_name)
      @file_name = file_name
    end

  end

end


