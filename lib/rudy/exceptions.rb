module Rudy
  
  class Error < RuntimeError
    def initialize(obj=nil); @obj = obj; end
    def message; "#{self.class}: #{@obj}"; end
  end
  class InsecureKeyPermissions < Rudy::Error
    def message
      lines = ["Insecure file permissions for #{@obj}"]
      lines << "Try: chmod 600 #{@obj}"
      lines.join($/)
    end
  end
  
  #--
  # TODO: Update exception Syntax based on:
  # http://blog.rubybestpractices.com/posts/gregory/anonymous_class_hacks.html
  #++
  
  class NoConfig < Rudy::Error
    def message; "No configuration found!"; end
  end
  class NoGlobal < Rudy::Error
    def message; "No globals defined!"; end
  end
  class NoMachinesConfig < Rudy::Error
    def message; "No machines configuration. Check your configs!"; end
  end
  class NoRoutinesConfig < Rudy::Error
    def message; "No routines configuration. Check your configs!"; end
  end
  class ServiceUnavailable < Rudy::Error
    def message; "#{@obj} is not available. Check your internets!"; end
  end
  class MachineGroupAlreadyRunning < Rudy::Error
    def message; "Machine group #{@obj} is already running."; end
  end
  class MachineGroupNotRunning < Rudy::Error
    def message; "Machine group #{@obj} is not running."; end
  end
  class MachineGroupMetadataExists < Rudy::Error 
    def message; "Machine group #{@obj} has existing metadata."; end
  end
  class MachineAlreadyRunning < Rudy::Error
    def message; "Machine #{@obj} is already running."; end
  end
  class MachineNotRunning < Rudy::Error
    def message; "Machine #{@obj} is not running."; end
  end
  class NoMachines < Rudy::Error;
    def message; "Specified remote machine(s) not running"; end
  end 
  class MachineGroupNotDefined < Rudy::Error 
    def message; "#{@obj} is not defined in machines config."; end
  end
  class PrivateKeyFileExists < Rudy::Error
    def message; "Private key #{@obj} already exists."; end
  end
  class PrivateKeyNotFound < Rudy::Error
    def message; "Private key file #{@obj} not found."; end
  end
  class UnsupportedOS < Rudy::Error; end

  
  class NotImplemented < Rudy::Error; end
  

  module Metadata
    class UnknownRecordType < Rudy::Error
      def message; "Unknown record type: #{@obj}"; end
    end
    class UnknownObject < Rudy::Error
      def message; "Unknown object: #{@obj}"; end
    end
    # Raised when trying to save a record with a key that already exists
    class DuplicateRecord < Rudy::Error; end
    
  end
  
  module Disks
    class NotAttached < Rudy::Error; end
    class NotFormatted < Rudy::Error; end
    class AlreadyFormatted < Rudy::Error; end
    class AlreadyMounted < Rudy::Error; end
    class AlreadyAttached < Rudy::Error; end
    class NotMounted < Rudy::Error; end
    class InUse < Rudy::Error; end
  end
  
  module Backups
    class NoDisk < Rudy::Error; end
  end
  
end