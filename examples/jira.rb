# NOTE: This configuration is in development and incomplete. 

defaults do
  color true
end

machines do
  
  region :'us-east-1' do
    ami 'ami-6f2cc906'               # Cloud Tools, CentOS 32-bit
  end
  
  env :stage do
    user :root
    size 'm1.small'                  # EC2 machine type for all machines
                                     # in the 'stage' environment
    role :app do      
      disks do                       # Define EBS volumes 
        path '/jira' do        # The paths can be anything but
          size 2                     # they must be unique. 
          device '/dev/sdr'          # Devices must be unique too.
        end
      end
    end

  end  

end

commands do
  allow :java
  allow :wget, 'wget', :q
end


routines do
  
  restore do
    adduser :jira
    authorize :jira
    network do
      authorize 8080
    end
    disks do
      restore "/jira"
    end
  end  
  
  startjira do
    remote :jira do
      cd '/jira/app'
      sh 'bin/startup.sh'
    end
  end
  
  stopjira do
    remote :jira do
      cd '/jira/app'
      sh 'bin/shutdown.sh'
    end
  end
  
  shutdown do
    before :stopjira, :archive
    disks do 
      destroy "/jira"
    end
  end
  
  archive do
    disks do
      archive "/jira"
    end
  end
  
  installjira do
    adduser :jira
    authorize :jira
    network do
      authorize 8080
    end
    disks do
      create "/jira"
    end
    remote :root do
      disable_safe_mode
      raise "JIRA is already installed" if file_exists? '/jira/app'
      jira_archive = "atlassian-jira-standard-3.13.5-standalone.tar.gz"
      unless file_exists? jira_archive
        wget "http://www.atlassian.com/software/jira/downloads/binary/#{jira_archive}"
      end
      cp jira_archive, '/jira/jira.tar.gz' 
      cd '/jira'
      mkdir :p, '/jira/indexes', '/jira/attachments', '/jira/backups'
      tar :x, :f, 'jira.tar.gz'
      mv 'atlassian-jira-*', 'app'
      chown :R, 'jira', '/jira'
      ls :l
    end
  end
  
end

