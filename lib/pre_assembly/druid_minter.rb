module PreAssembly

  class DruidMinter

    # A class to return new druids.
    # Used during integration tests when we need a druid but cannot
    # call the correct Dor service.

    @@druid = 'druid:aa000bb0000'

    def self.current
      return String.new(@@druid)
    end

    def self.next
      @@druid.next!
      self.current
    end

  end

end
