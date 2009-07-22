

module Rudy
  
  class Machines
    include Rudy::MetaData

    def create(&each_mach)
      raise MachineGroupAlreadyRunning, current_machine_group if running?
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      
      unless (1..MAX_INSTANCES).member?(current_machine_count)
        raise "Instance count must be more than 0, less than #{MAX_INSTANCES}"
      end

      unless @rgrp.exists?(current_group_name)
        puts "Creating group: #{current_group_name}"
        @rgrp.create(current_group_name)
      end

      unless @rkey.exists?(root_keypairname)
        kp_file = File.join(Rudy::CONFIG_DIR, root_keypairname)
        raise PrivateKeyFileExists, kp_file if File.exists?(kp_file)
        puts "Creating keypair: #{root_keypairname}"
        kp = @rkey.create(root_keypairname)
        puts "Saving #{kp_file}"
        Rudy::Utils.write_to_file(kp_file, kp.private_key, 'w', 0600)
      else
        kp_file = root_keypairpath
        # This means no keypair file can be found
        raise PrivateKeyNotFound, root_keypairname if kp_file.nil?
        # This means we found a keypair in the config but we cannot find the private key file.
        raise PrivateKeyNotFound, kp_file if !File.exists?(kp_file)
      end
      
      machines = []
      current_machine_count.times do |i|
        machine = Rudy::Machine.new

        #puts "Starting %s" % machine.name

        machine.start
        machines << machine
      end
      machines.each { |m| each_mach.call(m) } if each_mach
      machines
    end


    def destroy(&each_mach)
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      raise MachineGroupNotRunning, current_machine_group unless running?
      list.each { |m| each_mach.call(m); } if each_mach
      list do |mach|
        #puts "Destroying #{mach.name}"
        mach.destroy
      end
    end


    def restart(&each_mach)
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      raise MachineGroupNotRunning, current_machine_group unless running?
      machines = list
      machines.each do |mach|
        each_mach.call(mach) if each_mach
        puts "Restarting #{mach.name}"
        mach.restart
      end
      machines
    end

    def list(more=[], less=[], &each_mach)
      machines = list_as_hash(more, less, &each_mach)
      machines &&= machines.values
      machines
    end

    def list_as_hash(more=[], less=[], &each_mach)
      query = to_select([:rtype, 'm'], less)
      list = @sdb.select(query) || {}
      machines = {}
      list.each_pair do |n,m|
        machines[n] = Rudy::Machine.from_hash(m)
      end
      machines.each_pair { |n,mach| each_mach.call(mach) } if each_mach
      machines = nil if machines.empty?
      machines
    end

    def get(rname=nil)
      Rudy::Machine.from_hash(@sdb.get(Rudy::DOMAIN, rname)) # Returns nil if empty
    end


    def running?
      !list.nil?
      # TODO: add logic that checks whether the instances are running.
    end

  end


  class Machines::Offline
    def list(more=[], less=[], &each_mach)
      m = Rudy::Machine.new
      m.dns_public = 'localhost'
      each_mach.call(m) if each_mach
      [m]
    end
  end

end