
module Rudy; module Routines; module Handlers;
  module Host
    include Rudy::Routines::Handlers::Base
    extend self 
    
    ## NOTE: This handler doesn't use Rudy::Routines.add_handler
    
    def is_running?(rset)
      raise NoMachines if rset.boxes.empty?
      rset.boxes.each do |rbox|
        msg = "Waiting for #{rbox.nickname} to boot..."
        multi = rbox.stash.windows? ? 6 : 3
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
    # here ensures that the metadata is always up-to-date.
    # 
    # If a machine has an associated elastic IP address, it will also be
    # assigned in this step. 
    # 
    # Each Rye:Box instance has a Rudy::Machine instance in its stash so
    # rbox.stash.refresh! == machine.refresh!
    def update_dns(rset)
      raise NoMachines if rset.boxes.empty?
      rset.boxes.each do |rbox|
        mach = rbox.stash
        # Assign IP address only if we have one for that position
        if !mach.address.nil? && !mach.address.empty?
          begin
            # Make sure the address is associated to the current account
            if Rudy::AWS::EC2::Addresses.exists?(mach.address)
              li "Associating #{mach.address} to #{mach.instid}"
              Rudy::AWS::EC2::Addresses.associate(mach.address, mach.instid)
            else
              le "Unknown address: #{mach.address}"
            end
          rescue => ex
            le "Error associating address: #{ex.message}"
            ld ex.backtrace
          end
        end
        
        # Give EC2 some time to update their metadata
        msg = "Waiting for public DNS on #{rbox.nickname} ..."
        multi = rbox.stash.windows? ? 3 : 2
        interval, max = 2*multi, 60*multi
        Rudy::Utils.waiter(interval, max, STDOUT, msg, 0) {
          mach.refresh!
          if mach.address
            mach.dns_public.to_s =~ /#{mach.address.to_s.gsub('.', '-')}/
          else
            !mach.dns_public.nil? && !mach.dns_public.empty?
          end
        }
        rbox.host = mach.dns_public
      end
    end
    
    def is_available?(rset, port=22)
      raise NoMachines if rset.boxes.empty?
      rset.boxes.each do |rbox|
        mach = rbox.stash
        # This updates the DNS. It's important this happens
        # before and after the address is updated otherwise
        # certain errors will causes it to not be updated.  
        mach.refresh!
        msg = "Waiting for port #{port} on #{rbox.nickname} ..."
        port = 3389 if mach.windows?
        multi = mach.windows? ? 3 : 2
        interval, max = 1*multi, 30*multi
        Rudy::Utils.waiter(interval, max, STDOUT, msg, 0) {
          Rudy::Utils.service_available?(mach.dns_public, port)
        }
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
      hntype = current_machine_hostname || :rudy
      return if hntype.to_s.to_sym == :default
      rset.batch do
        unless self.stash.os == :windows
          hn = hntype == :rudy ? self.stash.name : hntype
          if self.user.to_s == 'root'  # ubuntu has a root user
            hostname hn
          else
            sudo do
              hostname hn
            end
          end
        end
      end
    end
    
  end
end; end; end