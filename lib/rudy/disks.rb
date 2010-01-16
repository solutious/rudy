

module Rudy
  
  module Disks
    RTYPE = 'disk'.freeze
    
    extend self
    extend Rudy::Metadata::ClassMethods
    include Rudy::Huxtable
    extend Rudy::Huxtable
    
    def get(path)
      tmp = Rudy::Disk.new path
      record = Rudy::Metadata.get tmp.name
      return nil unless record.is_a?(Hash)
      tmp.from_hash record
    end
    
    def from_hash(h)
      Rudy::Disk.from_hash h
    end
    
    def exists?(path)
      !get(path).nil?
    end
    
    
    class NotAttached < Rudy::Error; end
    class NotFormatted < Rudy::Error; end
    class AlreadyFormatted < Rudy::Error; end
    class AlreadyMounted < Rudy::Error; end
    class AlreadyAttached < Rudy::Error; end
    class NotMounted < Rudy::Error; end
    class InUse < Rudy::Error; end
    
  end
end