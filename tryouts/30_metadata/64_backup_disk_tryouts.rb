
group "Metadata"
library :rudy, 'lib'

Gibbler.enable_debug if Tryouts.verbose > 3
  
tryout "Disk Backups" do
  
  setup do
    #Rudy.enable_debug
    Rudy::Huxtable.update_config          # Read config files
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    Rudy::Metadata.connect akey, skey, region
    Rudy::AWS::EC2.connect akey, skey, region
    Rudy::Disk.new( 1, '/any/path').save
  end
  
  clean do
    Rudy::Disk.new( 1, '/any/path').destroy
    if Rudy.debug?
      puts $/, "Rudy Debugging:"
      Rudy::Huxtable.logger.rewind
      puts Rudy::Huxtable.logger.read unless Rudy::Huxtable.logger.closed_read?
    end
  end
  
  drill "no previous backups", false do
    Rudy::Backups.any?
  end
  
  dream :class, Array
  dream :size, 10
  drill "create 10 backups" do
    10.times do |i|
      seconds = i.to_s.rjust(2, '0')
      now = Time.parse("2009-01-01 00:00:#{seconds}")
      Rudy::Backup.new(1, '/any/path', :created => now).save
    end
    sleep 1 # eventual consistency
    Rudy::Backups.list
  end
  
  dream true
  drill "listed backups are in chronological order" do
    backups = Rudy::Backups.list
    stash :backups, backups
    prev = backups.shift
    success = false
    Rudy::Backups.list.each do |back|
      success = (prev.created <= back.created)
      break unless success
    end
    sleep 1
    success
  end
  
  drill "destroy all backups", false do
    Rudy::Backups.list.each { |b| b.destroy }
    sleep 1
    Rudy::Backups.any?
  end
  
end



