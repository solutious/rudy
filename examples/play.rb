# Rudy Gem Test
#
# This configuration is used to 
# test installing the Rudy gem. 

defaults do
  color true
  environment :test
  role :rudy
end

machines do
  region :'us-east-1' do
    ami 'ami-e348af8a'               # Alestic Debian 5.0, 32-bit (US)
  end
  env :test do
    role :rudy do
      user :root
    end
  end
  
  disks do
    path "/rudy/disk1"  do
      size 1
    end
  end
end

commands do
  allow :apt_get, "apt-get", :y, :q
  allow :gem_install, "/usr/bin/gem", "install", :n, '/usr/bin', :y, :V, "--no-rdoc", "--no-ri"
  allow :gem_sources, "/usr/bin/gem", "sources"
  allow :gem_uninstall, "/usr/bin/gem", "uninstall", :V, :y
  allow :update_rubygems
  allow :rake
  allow :rm
end

routines do
  
  create do
    disks do
      create "/rudy/disk1"
    end
  end
  
  fstype do
    disks do
      fstype "/rudy/disk1"
    end
  end
  
  sysupdate do
    remote :root do                  
      apt_get "update"               
      apt_get "install", "build-essential", "git-core"
      apt_get "install", "ruby1.8-dev", "rdoc", "libzlib-ruby", "rubygems"
      mkdir :p, "/var/lib/gems/1.8/bin" # Doesn't get created, but causes Rubygems to fail
      gem_install "builder", "session"
      gem_install 'rubygems-update', "-v=1.3.4"  # circular issue with 1.3.5 and hoe
      update_rubygems
    end
  end
  
  
  
end

