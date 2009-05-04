
# ----------------------------------------------------------- ROUTINES --------
# The routines block describes the repeatable processes for each machine group.
routines do
  
  
  #sysupdate do
  #  before :root do                  
  #    apt_get "update"               
  #    apt_get "install", "build-essential", "git-core"
  #    apt_get "install", "sqlite3", "libsqlite3-dev"
  #    apt_get "install", "ruby1.8-dev", "rubygems"
  #    apt_get "install", "apache2-prefork-dev", "libapr1-dev"
  #    apt_get "install", "libfcgi-dev", "libfcgi-ruby1.8"
  #    gem_sources :a, "http://gems.github.com"
  #  end
  #end
  #
  #installdeps do
  #  before :root do
  #    gem_install "test-spec", "rspec", "camping", "fcgi", "memcache-client"
  #    gem_install "mongrel"
  #    gem_install 'ruby-openid', :v, "2.0.4" # thin requires 2.0.x
  #    gem_install "rack", :v, "0.9.1"
  #    gem_install "macournoyer-thin"         # need 1.1.0 which works with rack 0.9.1
  #    gem_install "sinatra"
  #  end
  #end
  
  test1 do
    #adduser :delano
    #authorize :delano
    before :root do
      cat "rudy-config.yml"
      touch "2"
      rm "2"
    end

    #script :root do
    #  echo "root1"
    #end
    #script :delano do
    #  echo "delano2"
    #end
    #after :delano do
    #  ps
    #end
    after_local do
      ls :l
    end
  end
  
end

__END__

startup do      
  adduser :delano
  authorize :delano  
  disks do
    create "/rudy/disk1"
  end
end

authorize do
  adduser :delano
  authorize :delano
end

#release stage.app.startup      # Copy the startup routine
release do
  #changes :enforce
  git :delano do
    privatekey '/Users/delano/.ssh/git-delano_rsa'
    remote :origin
    path "/rudy/disk1/app/delanotes"
  end
  after :delano do
    thin :c, "/rudy/disk1/app/delanotes/", "start"
  end
end

rerelease do
  before :delano do
    thin :c, "/rudy/disk1/app/delanotes/", "stop"
  end
  git :delano do
    remote :origin
    path "/rudy/disk1/app/delanotes"
  end
  after :delano do
    thin :c, "/rudy/disk1/app/delanotes/", "start"
  end
end

restart do
  after :delano do
    thin :c, "/rudy/disk1/app/delanotes/", "restart"
  end
end

start do
  after :delano do
    thin :c, "/rudy/disk1/app/delanotes/", "start"
  end
end
stop do
  after :delano do
    thin :c, "/rudy/disk1/app/delanotes/", "stop"
  end
end

# This routine will be executed when you run "rudy shutdown"
shutdown do
  disks do
    # Rudy unmounts the EBS volume and deletes it. Careful! 
    destroy "/rudy/disk1"
  end
end

