

module Rudy
class Backups
  include Rudy::MetaData
  
    
  def create(&each_mach)
    
  end


  def destroy(&each_mach)
    list do |backup|
      puts "Destroying #{backup.name}"
      backup.destroy
    end
  end

  def list(more=[], less=[], &each_backup)
    backups = list_as_hash(&each_backup)
    backups &&= backups.values
    backups
  end

  def list_as_hash(more=[], less=[], &each_backup)
    query = to_select([:rtype, 'backup'], less)
    list = @sdb.select(query) || {}
    backups = {}
    list.each_pair do |n,d|
      backups[n] = Rudy::Backup.from_hash(d)
    end
    backups.each_pair { |n,backup| each_backup.call(backup) } if each_backup
    backups = nil if backups.empty?
    backups
  end

  def get(rname=nil)
    dhash = @sdb.get(Rudy::DOMAIN, rname)
    return nil if dhash.nil? || dhash.empty?
    d = Rudy::Backup.from_hash(dhash)
    d.update if d
    d
  end


  def running?
    !list.nil?
    # TODO: add logic that checks whether the instances are running.
  end


    
  
end
end

