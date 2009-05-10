

module Rudy
  module Routines
    class NoRoutine < Rudy::Error
      def message; "No routine configuration for #{@obj}"; end
    end
    
    class Base
      include Rudy::Huxtable
    
      def initialize(*args)
        a, s, r = @@global.accesskey, @@global.secretkey, @@global.region
        @sdb = Rudy::AWS::SDB.new(a, s, r)
        @rinst = Rudy::AWS::EC2::Instances.new(a, s, r)
        @rgrp = Rudy::AWS::EC2::Groups.new(a, s, r)
        @rkey = Rudy::AWS::EC2::KeyPairs.new(a, s, r)
        @rvol = Rudy::AWS::EC2::Volumes.new(a, s, r)
        @rsnap = Rudy::AWS::EC2::Snapshots.new(a, s, r)
        init(*args)
      end
      
      def init
      end
      
      def execute
        raise "Override execute method"
      end
      
      def raise_early_exceptions
        raise "Must override raise_early_exceptions"
      end
      
      # * +machine_action+ a method on Rudy::Machines, one of: create, destroy, list
      # * +routine+ Override +routine+ with another routine (default: nil)
      # * +skip_check+ Don't check that the machine is up and SSH is available (default: false)
      # * +skip_header+ Don't print machine header (default: false)
      # * +routine_action+ is an optional block which will be executed for each 
      #   machine between the disk routine and after blocks. The block receives
      #   two argument: an instance of Rudy::Machine and one of Rye::Box.
      def generic_machine_runner(machine_action, routine=nil, skip_check=false, skip_header=false, &routine_action)
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
        
        # This gets and removes the dependencies from the routines hash. 
        enjoy_every_sandwich {
          @before_dependencies = get_dependencies(:before, routine)
        
          # We grab the after ones now too, so we don't fool the ScriptHelper 
          # (the after keyword is used for both script and routine reference).  
          @after_dependencies = get_dependencies(:after, routine)
          
          # This calls generic_machine_runner for every dependent before routine
          run_dependencies(@before_dependencies, skip_check, skip_header)
        }
        
        
        lbox = Rye::Box.new('localhost')
        sconf = fetch_script_config
        
        enjoy_every_sandwich {
          if Rudy::Routines::ScriptHelper.before_local?(routine)  # before_local
            # Runs "before_local" scripts of routines config. 
            puts task_separator("LOCAL SHELL")
            Rudy::Routines::ScriptHelper.before_local(routine, sconf, lbox)
          end
        }
        
        enjoy_every_sandwich {
          if Rudy::Routines::ScriptHelper.script_local?(routine)  # script_local
            # Runs "script_local" scripts of routines config. 
            # NOTE: This is synonymous with before_local
            puts task_separator("LOCAL SHELL")
            Rudy::Routines::ScriptHelper.script_local(routine, sconf, lbox)
          end
        }
        
        unless has_remote_task?(routine)
          puts "[no remote tasks]"
          return
        end
        
        # Execute the action (create, list, destroy, restart) & apply the block to each
        rmach.send(machine_action) do |machine|
          puts machine_separator(machine.name, machine.awsid) unless skip_header
          
          unless skip_check
            msg = preliminary_separator("Checking if instance is running...")
            Rudy::Utils.waiter(3, 120, STDOUT, msg, 0) {
              inst = machine.get_instance
              inst && inst.running?
            } 
          
            # Add instance info to machine and save it. This is really important
            # for the initial startup so the metadata is updated right away. But
            # it's also important to call here because if a routine was executed
            # and an unexpected exception occurs before this update is executed
            # the machine metadata won't contain the DNS information. Calling it
            # here ensure that the metadata is always up-to-date. 
            machine.update 
          
            msg = preliminary_separator("Waiting for SSH daemon...")
            Rudy::Utils.waiter(2, 60, STDOUT, msg, 0) {
              Rudy::Utils.service_available?(machine.dns_public, 22)
            }
          end
          
          # TODO: trap rbox errors. We could get an authentication error. 
          opts = { :keys =>  root_keypairpath, :user => remote_user, :info => @@global.verbose > 0 }
          begin
            rbox = Rye::Box.new(machine.dns_public, opts)
            rbox.connect
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
                print preliminary_separator("Setting hostame to #{hn}... ")
                rbox.hostname(hn) 
                puts "done"
              end
            }
          end
          
          
          enjoy_every_sandwich {
            if Rudy::Routines::UserHelper.adduser?(routine)       # adduser
              puts task_separator("ADD USER")
              Rudy::Routines::UserHelper.adduser(routine, machine, rbox)
            end
          }
          
          enjoy_every_sandwich {
            if Rudy::Routines::UserHelper.authorize?(routine)     # authorize
              puts task_separator("AUTHORIZE USER")
              Rudy::Routines::UserHelper.authorize(routine, machine, rbox)
            end
          }
          
          enjoy_every_sandwich {
            if Rudy::Routines::ScriptHelper.before?(routine)      # before
              puts task_separator("REMOTE SHELL")
              Rudy::Routines::ScriptHelper.before(routine, sconf, machine, rbox)
            end
          }
          
          enjoy_every_sandwich {
            if Rudy::Routines::DiskHelper.disks?(routine)         # disk
              puts task_separator("DISKS")
              if rbox.ostype == "sunos"
                puts "Sorry, Solaris disks are not supported yet!"
              else
                Rudy::Routines::DiskHelper.execute(routine, machine, rbox)
              end    
            end
          }
          
          enjoy_every_sandwich {
            # Startup, shutdown, release, deploy, etc...
            routine_action.call(machine, rbox) if routine_action
          }
          
          # The "after" blocks are synonymous with "script" blocks. 
          # For some routines, like startup, it makes sense to an 
          # "after" block b/c "script" is ambiguous. In generic
          # routines, there is no concept of before or after. The
          # definition is the entire routine so we use "script".
          # NOTE: If both after and script are supplied they will 
          # both be executed. 
          enjoy_every_sandwich {
            if Rudy::Routines::ScriptHelper.script?(routine)      # script
              puts task_separator("REMOTE SHELL")
              # Runs "after" scripts of routines config
              Rudy::Routines::ScriptHelper.script(routine, sconf, machine, rbox)
            end
          }
          
          enjoy_every_sandwich {
            if Rudy::Routines::ScriptHelper.after?(routine)       # after
              puts task_separator("REMOTE SHELL")
              # Runs "after" scripts of routines config
              Rudy::Routines::ScriptHelper.after(routine, sconf, machine, rbox)
            end
          }
          
          rbox.disconnect
        end
        
        enjoy_every_sandwich {
          if Rudy::Routines::ScriptHelper.after_local?(routine)   # after_local
            puts task_separator("LOCAL SHELL")
            # Runs "after_local" scripts of routines config
            Rudy::Routines::ScriptHelper.after_local(routine, sconf, lbox)
          end
        }
        
        # This calls generic_machine_runner for every dependent after routine 
        enjoy_every_sandwich {
          run_dependencies(@after_dependencies, skip_check, skip_header)
        }
        
      end
      
      
      # Returns an Array of the dependent routines for the given +timing+ (before/after)
      def get_dependencies(timing, routine)
        return if !(routine.is_a?(Caesars::Hash) && routine[timing].is_a?(Caesars::Hash))
        
        # This will produce an Array containing the routines to run. The 
        # elements are the valid routine names. 
        # NOTE: The "timing" elements are removed from the routines hash. 
        dependencies = []
        routine[timing].each_pair do |n,v| 
          next unless v.nil?  # this skips all "script" blocks
          raise "#{timing}: #{n} is not a known routine" unless valid_routine?(n)
          routine[timing].delete(n)
          dependencies << n
        end

        # We need to return only the keys b/c the values are nil
        dependencies = nil if dependencies.empty?
        dependencies
      end
      
      def run_dependencies(depends, skip_check, skip_header)
        return unless depends
        unless depends.empty?
          depends.each_with_index do |d, index|
            puts task_separator("DEPENDENCY: #{d}")  
            routine_dependency = fetch_routine_config(d)
            unless routine_dependency
              STDERR.puts "  Unknown routine: #{d}".color(:red)
              next
            end
            # NOTE: running routines here means they do not have their own
            # payload and they must use the list action. I think this is ok
            # though b/c there should only be a few routines with payloads
            # (startup, shutdown, reboot)
            generic_machine_runner(:list, routine_dependency, skip_check, skip_header)
          end
        end
      end
      
      # Does the given +routine+ define any remote tasks?
      def has_remote_task?(routine)
        any = [Rudy::Routines::DiskHelper.disks?(routine),
               Rudy::Routines::ScriptHelper.before?(routine),
               Rudy::Routines::ScriptHelper.after?(routine),
               Rudy::Routines::ScriptHelper.script?(routine),
               Rudy::Routines::UserHelper.authorize?(routine),
               Rudy::Routines::UserHelper.adduser?(routine), 
               !@after_dependencies.nil?,
               !@before_dependencies.nil?]
        # Throw away all false answers (and nil answers)
        any = any.compact.select { |success| success }
        !any.empty?   # Returns true if any element contains true
      end
      
      def preliminary_separator(msg)
        # TODO: Count number messages printed 1/3. ie:
        # m-us-east-1b-stage-app-01                   
        #   (1/3) Checking if instance is running... done
        #   (2/3) Waiting for SSH daemon... done
        #   (3/3) Setting hostame to m-us-east-1b-stage-app-01... done
        ("  -> #{msg}")
      end
      
      def task_separator(title)
        dashes = 59 - title.size 
        dashes = 0 if dashes < 1
        ("%s---  %s  %s" % [$/, title, '-'*dashes])
      end
      
      def machine_separator(name, awsid)
        ('%s %-63s awsid: %s ' % [$/, name, awsid]).att(:reverse)
      end
      
      def routine_separator(name)
        # Not used (for now)
        name = name.to_s
        dashes = 59 - name.size # 
        dashes = 0 if dashes < 1
        #puts '%-40s' % [name.bright]
      end
      
      def enjoy_every_sandwich(&bloc_party)
        begin
          bloc_party.call
        rescue => ex
          STDERR.puts "  Error: #{ex.message}".color(:red)
          STDERR.puts ex.backtrace if Rudy.debug?
          exit 12 unless keep_going?
        end
      end
      
       def keep_going?
         Annoy.pose_question("  Keep going?\a ", /yes|y|ya|sure|you bet!/i, STDERR)
       end
      
    end
  end
end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'routines', '*.rb')
Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'routines', 'helpers', '*.rb')


