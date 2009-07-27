

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
    
  end
end