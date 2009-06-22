
module Rudy; module Routines; 
  module HostHelper
    include Rudy::Routines::HelperBase  # TODO: use trap_rbox_errors
    extend self 
    
    ## NOTE: This helper doesn't use Rudy::Routines.add_helper
    
    def is_running?(rset)
      raise NoMachines if rset.boxes.empty?
      rset.batch(rset.parallel) do |parallel|
        msg = "Starting #{self.nickname}..."
        output = parallel ? nil : Rudy::Huxtable.logger 
        Rudy::Utils.waiter(3, 120, output, msg, 0) {
          inst = self.stash.get_instance
          inst && inst.running?
        }
      end
    end
    
    # Add instance info to machine and save it. This is really important
    # for the initial startup so the metadata is updated right away. But
    # it's also important to call here because if a routine was executed
    # and an unexpected exception occurs before this update is executed
    # the machine metadata won't contain the DNS information. Calling it
    # here ensure that the metadata is always up-to-date.
    # Each Rye:Box instance has a Rudy::Machine instance in its stash so
    # self.stash.update == machine.update
    def update_dns(rset)
      raise NoMachines if rset.boxes.empty?
      rset.batch do 
        self.stash.update 
        self.host = self.stash.dns_public
      end
    end
    
    def is_available?(rset, port=22)
      raise NoMachines if rset.boxes.empty?
      rset.batch(rset.parallel, port) do |parallel,p|
        # Windows machine do not have an SSH daemon
        unless (self.stash.os || '').to_s == 'win32'
          msg = parallel ? nil : "Waiting for #{self.nickname}:#{p}..."
          Rudy::Utils.waiter(2, 30, STDOUT, msg, 0) {
            Rudy::Utils.service_available?(self.stash.dns_public, p)
          }
        end
      end
    end
    
    def set_hostname(rset)
      raise NoMachines if rset.boxes.empty?
      # Set the hostname if specified in the machines config. 
      # :rudy -> change to Rudy's machine name
      # :default -> leave the hostname as it is
      # Anything else other than nil -> change to that value
      # NOTE: This will set hostname every time a routine is
      # run so we may want to make this an explicit action.
      type = current_machine_hostname || :rudy
      rset.batch(type) do |hn|
        if hn != :default
          hn = self.stash.name if hn == :rudy
          self.hostname(hn) 
        end
      end
    end
    
  end
end; end