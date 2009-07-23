

module Rudy
  
  module Disks
    extend self
    include Rudy::Huxtable
    
    def get(path)
      tmp = Rudy::Disk.new path
      record = Rudy::Metadata.get tmp.name
      return nil unless record.is_a?(Hash)
      tmp.from_hash record
    end
    
  end
end