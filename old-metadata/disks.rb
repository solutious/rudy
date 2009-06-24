

module Rudy
class Disks
  include Rudy::Metadata
  
  
  def init
    @rback = Rudy::Backups.new
  end
  
  #def create(&each_mach)
    
  #end


  def destroy(&each_mach)
    #raise MachineGroupNotRunning, current_machine_group unless running?
    #raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
    list do |disk|
      puts "Destroying #{disk.name}"
      disk.destroy
    end
  end
  
  def backups
    @rback.list()
  end
  
  def list(more=[], less=[], &each_disk)
    disks = list_as_hash(&each_disk)
    disks &&= disks.values
    disks
  end
  
  def list_as_hash(more=[], less=[], &each_disk)
    query = to_select([:rtype, 'disk'], less)
    list = @sdb.select(query) || {}
    disks = {}
    list.each_pair do |n,d|
      disks[n] = Rudy::Metadata::Disk.from_hash(d)
    end
    disks.each_pair { |n,disk| each_disk.call(disk) } if each_disk
    disks = nil if disks.empty?
    disks
  end

  def get(rname=nil)
    dhash = @sdb.get(Rudy::DOMAIN, rname)
    return nil if dhash.nil? || dhash.empty?
    d = Rudy::Metadata::Disk.from_hash(dhash)
    d.update if d
    d
  end


  def running?
    !list.nil?
    # TODO: add logic that checks whether the instances are running.
  end


    
  
end
end

