module PreAssembly

  class DruidMinter

    @@druid = 'druid:aa000bb0000'

    def self.current
      @@druid
    end

    def self.next
      String.new @@druid.next!
    end

  end

end
