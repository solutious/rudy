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
end

commands do
  allow :apt_get, "apt-get", :y, :q
  allow :gem_install, "/usr/bin/gem", "install", :n, '/usr/bin', :y, :V, "--no-rdoc", "--no-ri"
  allow :gem_sources, "/usr/bin/gem", "sources"
  allow :gem_uninstall, "/usr/bin/gem", "uninstall", :V
  allow :update_rubygems
  allow :rake
  allow :rm
end

routines do
  
  install_rubyforge do
    remote :root do
      gem_install 'rudy', :V
    end
  end

  install_github do
    remote :root do
      gem_sources :a, "http://gems.github.com"
      gem_install 'solutious-rudy'
    end
  end
  
  package_gem do
    local do
      rm :r, :f, 'pkg'
      rake 'package'
    end
  end
  
  install_gem do
    before :package_gem
    remote :root do
      file_upload "pkg/rudy-#{Rudy::VERSION}.gem", "/tmp/"
      gem_install "/tmp/rudy-#{Rudy::VERSION}.gem"
    end
  end
  
  remove_rudy do
    remote :root do
      gem_uninstall 'rudy'
      rm :r, :f, '.rudy'
    end
  end
  
  init_rudy do
    before :install_gem
    remote do
      disable_safe_mode
      rudy :v, :v, 'init'  # create home directory
      file_upload File.expand_path('~/.rudy/config'), '.rudy/'
      ls :l, '.rudy/config'
      rudy :v, :v, 'init'
      rudy 'info', :l
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
  
  startup do
    after :sysupdate
  end
end

