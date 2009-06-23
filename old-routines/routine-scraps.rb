
# * +machine_action+ a method on Rudy::Machines, one of: create, destroy, list
# * +routine+ Override +routine+ with another routine (default: nil)
# * +skip_check+ Don't check that the machine is up and SSH is available (default: false)
# * +skip_header+ Don't print machine header (default: false)
# * +routine_action+ is an optional block which will be executed for each 
#   machine between the disk routine and after blocks. The block receives
#   two argument: an instance of Rudy::Machine and one of Rye::Box.
def generic_machine_runner(machine_action, routine=nil, skip_check=false, skip_header=false, &routine_action)
  is_available= false
  
  if @@global.offline
    rmach = Rudy::Machines::Offline.new
    skip_check = true
    remote_user = Rudy.sysinfo.user
  else
    rmach = Rudy::Machines.new
    remote_user = 'root'
  end
  
  routine ||= @routine
  raise "No routine supplied" unless routine
  raise "No machine action supplied" unless machine_action
  unless rmach.respond_to?(machine_action)
    raise "Unknown machine action #{machine_action}" 
  end
  
  # Declare a couple vars so they're available outide the block
  before_dependencies = after_dependencies = nil  
  enjoy_every_sandwich {
    # This gets and removes the dependencies from the routines hash. 
    if Rudy::Routines::Handlers::Depends.has_depends?(:before, routine)
      before_dependencies = Rudy::Routines::Handlers::Depends.get(:before, routine)
    end
    
    # We grab the after ones now too, so we don't fool the ScriptHelper 
    # later on in this routine (after keyword is used for scripts too)
    if Rudy::Routines::Handlers::Depends.has_depends?(:after, routine)
      after_dependencies = Rudy::Routines::Handlers::Depends.get(:after, routine)
    end
    
    # This calls generic_machine_runner for every dependent before routine. 
    execute_dependency(before_dependencies, skip_check, skip_header)
  }
  
  
  lbox = Rye::Box.new('localhost', :info => (@@global.verbose > 3), :debug => false)
  sconf = fetch_script_config
  
  enjoy_every_sandwich {
    if Rudy::Routines::Handlers::Script.before_local?(routine)  # before_local
      # Runs "before_local" scripts of routines config. 
      task_separator("LOCAL SHELL")
      lbox.cd Dir.pwd # Run local command block from current working directory
      Rudy::Routines::Handlers::Script.before_local(routine, sconf, lbox, @option, @argv)
    end
  }
  
  enjoy_every_sandwich {
    if Rudy::Routines::Handlers::Script.script_local?(routine)  # script_local
      # Runs "script_local" scripts of routines config. 
      # NOTE: This is synonymous with before_local
      task_separator("LOCAL SHELL")
      lbox.cd Dir.pwd # Run local command block from current working directory
      Rudy::Routines::Handlers::Script.script_local(routine, sconf, lbox, @option, @argv)
    end
  }
  
  # Execute the action (create, list, destroy, restart)
  machines = enjoy_every_sandwich([]) { rmach.send(machine_action) } || []
  
  machines.each do |machine|
    puts machine_separator(machine.name, machine.awsid) unless skip_header
    
    unless skip_check
      msg = preliminary_separator("Checking if instance is running...")
      Rudy::Utils.waiter(3, 120, STDOUT, msg, 0) {
        inst = machine.get_instance
        inst && inst.running?
      } 
    end
    
    # Add instance info to machine and save it. This is really important
    # for the initial startup so the metadata is updated right away. But
    # it's also important to call here because if a routine was executed
    # and an unexpected exception occurs before this update is executed
    # the machine metadata won't contain the DNS information. Calling it
    # here ensure that the metadata is always up-to-date. 
    machine.update 
    
    # This is a short-circuit for Windows instances. We don't support
    # disks for windows yet and there's no SSH so routines are out of
    # the picture too. Here we simply run the per machine block which
    # is crucial for shutdown and possibly others as well. 
    if (machine.os || '').to_s == 'win32'
      enjoy_every_sandwich {
        # Startup, shutdown, release, deploy, etc...
        routine_action.call(machine, nil) if routine_action
      }
      
      next  # The short circuit
    end
      
    if !skip_check && has_remote_task?(routine)
      enjoy_every_sandwich {
        msg = preliminary_separator("Waiting for SSH daemon...")
        ret = Rudy::Utils.waiter(2, 30, STDOUT, msg, 0) {
          Rudy::Utils.service_available?(machine.dns_public, 22)
        }
        is_available = ret
      }
    end
    
    if is_available
      # TODO: trap rbox errors. We could get an authentication error. 
      opts = { :keys =>  root_keypairpath, :user => remote_user, 
               :info => @@global.verbose > 3, :debug => false }
      begin
        rbox = Rye::Box.new(machine.dns_public, opts)
        Rudy::Utils.waiter(2, 10, STDOUT, nil, 0) { rbox.connect }
      rescue Rye::NoHost => ex
        STDERR.puts "No host: #{ex.message}"
        exit 65
      end
    
      unless skip_check
        # Set the hostname if specified in the machines config. 
        # :rudy -> change to Rudy's machine name
        # :default -> leave the hostname as it is
        # Anything else other than nil -> change to that value
        # NOTE: This will set hostname every time a routine is
        # run so we may want to make this an explicit action. 
        enjoy_every_sandwich {
          hn = current_machine_hostname || :rudy
          if hn != :default
            hn = machine.name if hn == :rudy
            print preliminary_separator("Setting hostname to #{hn}... ")
            rbox.hostname(hn) 
            puts "done"
          end
        }
      end
    
    
      ## NOTE: This prevents shutdown from doing its thing and prob
      ## isn't necessary. 
      ##unless has_remote_task?(routine) 
      ##  puts "[no remote tasks]"
      ##  next
      ##end

      enjoy_every_sandwich {
        if Rudy::Routines::Handlers::User.adduser?(routine)       # adduser
          task_separator("ADD USER")
          Rudy::Routines::Handlers::User.adduser(routine, machine, rbox)
        end
      }
    
      enjoy_every_sandwich {
        if Rudy::Routines::Handlers::User.authorize?(routine)     # authorize
          task_separator("AUTHORIZE USER")
          Rudy::Routines::Handlers::User.authorize(routine, machine, rbox)
        end
      }
    
      enjoy_every_sandwich {
        if Rudy::Routines::Handlers::Script.before?(routine)      # before
          task_separator("REMOTE SHELL")
          Rudy::Routines::Handlers::Script.before(routine, sconf, machine, rbox, @option, @argv)
        end
      }
    
      enjoy_every_sandwich {
        if Rudy::Routines::Handlers::Disk.disks?(routine)         # disk
          task_separator("DISKS")
          ##if rbox.ostype == "sunos"
          ##  puts "Sorry, Solaris disks are not supported yet!"
          ##else
            Rudy::Routines::Handlers::Disk.execute(routine, machine, rbox)
          ##end    
        end
      }
    
    end
    
    enjoy_every_sandwich {
      # Startup, shutdown, release, deploy, etc...
      routine_action.call(machine, rbox) if routine_action
    }
    
    
    if is_available
      # The "after" blocks are synonymous with "script" blocks. 
      # For some routines, like startup, it makes sense to an 
      # "after" block b/c "script" is ambiguous. In generic
      # routines, there is no concept of before or after. The
      # definition is the entire routine so we use "script".
      # NOTE: If both after and script are supplied they will 
      # both be executed. 
      enjoy_every_sandwich {
        if Rudy::Routines::Handlers::Script.script?(routine)      # script
          task_separator("REMOTE SHELL")
          # Runs "after" scripts of routines config
          Rudy::Routines::Handlers::Script.script(routine, sconf, machine, rbox, @option, @argv)
        end
      }
    
      enjoy_every_sandwich {
        if Rudy::Routines::Handlers::Script.after?(routine)       # after
          task_separator("REMOTE SHELL")
          # Runs "after" scripts of routines config
          Rudy::Routines::Handlers::Script.after(routine, sconf, machine, rbox, @option, @argv)
        end
      }
    
      rbox.disconnect
    end
  end

  enjoy_every_sandwich {
    if Rudy::Routines::Handlers::Script.after_local?(routine)   # after_local
      task_separator("LOCAL SHELL")
      lbox.cd Dir.pwd # Run local command block from current working directory
      # Runs "after_local" scripts of routines config
      Rudy::Routines::Handlers::Script.after_local(routine, sconf, lbox, @option, @argv)
    end
  }
  
  # This calls generic_machine_runner for every dependent after routine 
  enjoy_every_sandwich {
    execute_dependency(after_dependencies, skip_check, skip_header)
  }
  
  machines
end




# Does the given +routine+ define any remote tasks?
def has_remote_task?(routine)
  any = [Rudy::Routines::Handlers::Disk.disks?(routine),
         Rudy::Routines::Handlers::Script.before?(routine),
         Rudy::Routines::Handlers::Script.after?(routine),
         Rudy::Routines::Handlers::Script.script?(routine),
         Rudy::Routines::Handlers::User.authorize?(routine),
         Rudy::Routines::Handlers::User.adduser?(routine), 
         !@after_dependencies.nil?,
         !@before_dependencies.nil?]
  # Throw away all false answers (and nil answers)
  any = any.compact.select { |success| success }
  !any.empty?   # Returns true if any element contains true
end

def task_separator(title)
  dashes = 59 - title.size 
  dashes = 0 if dashes < 1
  puts ("%s---  %s  %s" % [$/, title, '-'*dashes]) if @@global.verbose > 2
end


def routine_separator(name)
  # Not used (for now)
  name = name.to_s
  dashes = 59 - name.size # 
  dashes = 0 if dashes < 1
  #puts '%-40s' % [name.bright]
end
