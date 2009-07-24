
group "rudy-ec2"
command :rudy, File.expand_path(File.join(GYMNASIUM_HOME, '..', 'bin', 'rudy'))
xtryouts "Zones" do
  dream :stdout do
  end
  drill "list zones", :zones
end
