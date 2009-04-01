#--
# TODO: Handle nested hashes and arrays. 
# TODO: to_xml, see: http://codeforpeople.com/lib/ruby/xx/xx-2.0.0/README
# TODO: Rename to Stuffany
#++

require 'yaml'
require 'fileutils'

module MetaData
  extend self
  @@paul = "front"
  
  def paul
    @@paul
  end
end

class Disk < Storable
  include MetaData
  extend MetaData
  field :poop
  field :help
  

end

class Disks
  def find *args
  end
  
  def exists? *args
  end
  
end

d = Disk.new
d.poop = "100a"
d.help = true

puts d.paul
puts Disk.paul
puts Disk.superclass::VERSION

Disks.find disk_name
Disks.find :env => 'prod', :role => 'app'
Disks.exists? disk_name








