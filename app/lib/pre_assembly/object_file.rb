# frozen_string_literal: true

module PreAssembly
  # an individual file within a digital object; extends class from assembly-objectfile gem
  class ObjectFile < Assembly::ObjectFile
    # This is a bit of a lie. ObjectFiles with the same relative_path but different digests
    # are clearly not representing the same thing.
    def <=>(other)
      relative_path <=> other.relative_path
    end
  end
end
