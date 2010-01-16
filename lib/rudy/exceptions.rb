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
    def message
      msg = "No machines running "
      msg << "in #{@obj}" if @obj
      msg
    end
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
  
  
end