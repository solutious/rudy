
module Rudy; module Routines; module Handlers;
  module Host
    include Rudy::Routines::Handlers::Base
    extend self 
    
    ## NOTE: This handler doesn't use Rudy::Routines.add_handler
    
    def is_running?(rset)
      raise NoMachines if rset.boxes.empty?
      rset.boxes.each do |rbox|
        msg = "Waiting for #{rbox.nickname} to boot..."
        multi = rbox.stash.win32? ? 6 : 3
        interval, max = 1*multi, 80*multi
        Rudy::Utils.waiter(interval, max, Rudy::Huxtable.logger, msg, 0) {
          inst = rbox.stash.get_instance
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
    # rbox.stash.refresh! == machine.refresh!
    def update_dns(rset)
      raise NoMachines if rset.boxes.empty?
      rset.boxes.each do |rbox|
        rbox.stash.refresh! 
        rbox.host = rbox.stash.dns_public
      end
    end
    
    def is_available?(rset, port=22)
      raise NoMachines if rset.boxes.empty?
      rset.boxes.each do |rbox|
        port = 3389 if rbox.stash.win32?
        msg = "Waiting for port #{port} on #{rbox.nickname} ..."
        Rudy::Utils.waiter(2, 60, STDOUT, msg, 0) {
          Rudy::Utils.service_available?(rbox.stash.dns_public, port)
        }
      end
    end
    
    def set_hostname(rset)
      raise NoMachines if rset.boxes.empty?
      
      original_user = rset.user
      rset.switch_user 'root' 
      rset.add_key user_keypairpath('root')
      # Set the hostname if specified in the machines config. 
      # :rudy -> change to Rudy's machine name
      # :default -> leave the hostname as it is
      # Anything else other than nil -> change to that value
      # NOTE: This will set hostname every time a routine is
      # run so we may want to make this an explicit action.
      type = current_machine_hostname || :rudy
      rset.batch(type) do |hn|
        unless self.stash.os == :win32
          if hn != :default
            hn = self.stash.name if hn == :rudy
            self.quietly { hostname(hn) }
          end
        end
      end
      rset.switch_user original_user
    end
    
  end
end; end; end