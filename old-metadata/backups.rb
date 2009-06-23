

module Rudy
class Backups
  include Rudy::MetaData
  
  def init
    now = Time.now.utc
    datetime = Rudy::MetaData::Backup.format_timestamp(now).split(Rudy::DELIM)
    @created = now.to_i
    @date, @time, @second = datetime
  end
  
  #def create(&each_mach)
    
  #end


  def destroy(&each_mach)
    list do |backup|
      puts "Destroying #{backup.name}"
      backup.destroy
    end
  end

  def list(more=[], less=[], local={}, &each_backup)
    backups = list_as_hash(more, less, local, &each_backup)
    backups &&= backups.values
    backups
  end

  def list_as_hash(more=[], less=[], local={}, &each_backup)
    more ||= []
    more += [:rtype, 'back']
    query = to_select(more, less, local)
    list = @sdb.select(query) || {}
    backups = {}
    list.each_pair do |n,d|
      backups[n] = Rudy::MetaData::Backup.from_hash(d)
    end
    backups.each_pair { |n,backup| each_backup.call(backup) } if each_backup
    backups = nil if backups.empty?
    backups
  end

  def get(rname=nil)
    dhash = @sdb.get(Rudy::DOMAIN, rname)
    return nil if dhash.nil? || dhash.empty?
    d = Rudy::MetaData::Backup.from_hash(dhash)
    d.update if d
    d
  end


  def running?
    !list.nil?
    # TODO: add logic that checks whether the instances are running.
  end

  def to_select(*args)
    query = super(*args)
    query << " and created != '0' order by created desc"
  end
  
end
end

