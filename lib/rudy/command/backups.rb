

module Rudy
  class Backups
    
  end
end


__END__


# From Rudy::MetaData::Backup

def Backup.for_disk(sdb, disk, max=50)
  list = Backup.list(sdb, disk.zone, disk.environment, disk.role, disk.position, disk.path) || []
  list[0..(max-1)]
end

def Backup.get(sdb, name)
  object = sdb.get_attributes(Rudy::DOMAIN, name)
  raise "Object #{name} does not exist!" unless object.has_key?(:attributes) && !object[:attributes].empty?
  self.from_hash(object[:attributes])
end

def Backup.save(sdb, obj, replace = :replace)
  sdb.store(Rudy::DOMAIN, obj.name, obj.to_hash, replace)
end

def Backup.list(sdb, zon, env=nil, rol=nil, pos=nil, path=nil, date=nil)
  query = "select * from #{Rudy::DOMAIN} where "
  query << "rtype = '#{rtype}' "
  query << " and zone = '#{zon}'" if zon
  query << " and environment = '#{env}'" if env
  query << " and role = '#{rol}'" if rol
  query << " and position = '#{pos}'" if pos
  query << " and path = '#{path}'" if path
  query << " and date = '#{date}'" if date
  query << " and unixtime != '0' order by unixtime desc"
  list = []
  sdb.select(query).each do |obj|
    list << self.from_hash(obj)
  end
  list
end

def Backup.find_most_recent(zon, env, rol, pos, path)
  criteria = [zon, env, rol, pos, path]
  (Rudy::MetaData::Backup.list(@sdb, *criteria) || []).first
end

def Backup.destroy(sdb, name)
  back = Backup.get(sdb, name) # get raises an exception if the disk doesn't exist
  sdb.destroy(Rudy::DOMAIN, name)
  true 
end



def Backup.is_defined?(sdb, backup)
  query = backup.to_query()
  puts query
  !sdb.select(query).empty?
end

