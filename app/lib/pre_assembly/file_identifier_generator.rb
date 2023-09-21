# frozen_string_literal: true

module PreAssembly
  # Generates a unique external identifier for a Cocina File
  # The primary reason for abstracting this is for ease of mocking,
  # since SecureRandom is used by the test framework.
  class FileIdentifierGenerator
    def self.generate
      "https://cocina.sul.stanford.edu/file/#{SecureRandom.uuid}"
    end
  end
end
