

module Rudy
  module CLI
    class Release < Rudy::CLI::Base
      
      

      
      def release_valid?
        
        relroutine = @config.routines.find_deferred(@global.environment, @global.role, :release)
        raise "No release routines defined for #{machine_group}" if relroutine.nil?
        
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user} in #{machine_group}!" unless has_keypair?
        raise "No SSH key provided for root in #{machine_group}!" unless has_keypair?(:root)
        
        @list = @ec2.instances.list(machine_group)
        unless @list.empty?
          msg = "#{machine_group} is in use, probably with another release. #{$/}"
          msg << 'Sort it out and run "rudy shutdown" before continuing.' 
          raise msg
        end
        
        @scm, @scm_params = find_scm(:release)
        
        raise "No SCM defined for release routine" unless @scm        
        raise "#{Dir.pwd} is not a working copy" unless @scm.working_copy?(Dir.pwd)
        raise "There are local changes. Please revert or check them in." unless @scm.everything_checked_in?
        raise "Invalid base URI (#{@scm_params[:base]})." unless @scm.valid_uri?(@scm_params[:base])
        
        true
      end
      
      
      
      def rerelease_valid?
        relroutine = @config.routines.find_deferred(@global.environment, @global.role, :rerelease)
        raise "No rerelease routines defined for #{machine_group}" if relroutine.nil?
        
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user} in #{machine_group}!" unless has_keypair?
        raise "No SSH key provided for root in #{machine_group}!" unless has_keypair?(:root)
        
        @list = @ec2.instances.list(machine_group)
        if @list.empty?
          msg = "There are no machines running in #{machine_group}. #{$/}"
          msg << 'You must run "rudy release" before you can rerelease.' 
          raise msg
        end
        
        @scm, @scm_params = find_scm(:rerelease)
        
        raise "No SCM defined for release routine" unless @scm        
        raise "#{Dir.pwd} is not a working copy" unless @scm.working_copy?(Dir.pwd)
        raise "There are local changes. Please revert or check them in." unless @scm.everything_checked_in?
        raise "Invalid base URI (#{@scm_params[:base]})." unless @scm.valid_uri?(@scm_params[:base])
        
        true
      end
      
      def rerelease
        puts "Updating release from working copy".att(:bright)

        tag, revision = @scm.local_info
        puts "tag: #{tag}"
        puts "rev: #{revision}"
        
        execute_disk_routines(@list.values, :rerelease)
        
        if @scm
          
          puts "Running SCM command".att(:bright)
          ssh do |session|
            cmd = "svn #{@scm_params[:command]}"
            puts "#{cmd}"
            session.exec!("cd #{@scm_params[:path]}")
            session.exec!(cmd)
            puts "#{@scm_params[:command]} complete"
          end
          
        end
        
        execute_routines(@list.values, :rerelease, :after)
        
      end
      
      # <li>Creates a release tag based on the working copy on your machine</li>
      # <li>Starts a new stage instance</li>
      # <li>Executes release routines</li>
      def release
        # TODO: store metadata about release with local username and hostname
        puts "Creating release from working copy".att(:bright)

        exit unless Annoy.are_you_sure?(:low)

        tag = @scm.create_release(@global.local_user, @option.msg)        
        puts "Done! (#{tag})"
        
        if @option.switch
          puts "Switching working copy to new tag".att(:bright)
          @scm.switch_working_copy(tag)
        end
        
        @option.image ||= machine_image
        
        switch_user("root")
        
        puts "Starting #{machine_group}".att(:bright)
        
        instances = @ec2.instances.create(@option.image, machine_group.to_s, File.basename(keypairpath), machine_data.to_yaml, @global.zone)
        inst = instances.first
        
        if @option.address ||= machine_address
          puts "Associating #{@option.address} to #{inst[:aws_instance_id]}".att(:bright)
          @ec2.addresses.associate(inst[:aws_instance_id], @option.address)
        end
        
        wait_for_machine(inst[:aws_instance_id])
        inst = @ec2.instances.get(inst[:aws_instance_id])
        
        #inst = @ec2.instances.list(machine_group).values
        
        
        execute_disk_routines(inst, :release)
        
        if @scm
          
          puts "Running SCM command".att(:bright)
          ssh do |session|
            cmd = "svn #{@scm_params[:command]} #{tag} #{@scm_params[:path]}"
            puts "#{cmd}"
            session.exec!(cmd)
            puts "#{@scm_params[:command]} complete"
          end
          
        end
        
        execute_routines(inst, :release, :after)
        
        print_instance inst
        
        puts "Done!"
      end
      
      
      def find_scm(routine)
        env, rol, att = @global.environment, @global.role
        
        # Look for the source control engine, checking all known scm values.
        # The available one will look like [environment][role][release][svn]
        params = nil
        scm_name = nil
        SUPPORTED_SCM_NAMES.each do |v|
          scm_name = v
          params = @config.routines.find(env, rol, routine, scm_name)
          break if params
        end
        
        if params
          klass = eval "Rudy::SCM::#{scm_name.to_s.upcase}"
          scm = klass.new(:base => params[:base])
        end
        
        [scm, params]
        
      end
      private :find_scm
      
    end
  end
end

