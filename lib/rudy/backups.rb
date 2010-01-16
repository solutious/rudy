module Rudy
  
  module Backups
    RTYPE = 'back'.freeze
    
    extend self
    extend Rudy::Metadata::ClassMethods 
    include Rudy::Huxtable
    extend Rudy::Huxtable
    
    # Returns the most recent backup object for the given path
    def get(path)
      tmp = Rudy::Backup.new path
      backups = Rudy::Backups.list :path => path
      return nil unless backups.is_a?(Array) && !backups.empty?
      backups.first
    end
    
    def from_hash(h)
      Rudy::Backup.from_hash h
    end
    
    class NoDisk < Rudy::Error; end
    class NoBackup < Rudy::Error; end
    
  end
  
end