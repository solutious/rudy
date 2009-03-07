

module Rudy
  module Command
    class Release < Rudy::Command::Base
      
      

      
      def release_valid?
        
        relroutine = @config.machinegroup.find_deferred(@global.environment, @global.role, :release)
        raise "No release routines defined for #{machine_group}" if relroutine.nil?
        
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user} in #{machine_group}!" unless has_keypair?
        raise "No SSH key provided for root in #{machine_group}!" unless has_keypair?(:root)
        
        @list = @ec2.instances.list(machine_group)
        unless @list.empty?
          msg = "#{machine_group} is in use, probably with another release. #{$/}"
          msg << 'Sort it out and run "rudy destroy" before continuing.' 
          raise msg
        end
        
        @scm, @scm_params = find_scm
                
        raise "#{Dir.pwd} is not a working copy" unless @scm.svn_dir?(Dir.pwd)
        raise "There are local changes. Please revert or check them in." unless @scm.everything_checked_in?
        raise "Invalid base URI (#{@scm_params[:base]})." unless @scm.valid_uri?(@scm_params[:base])
        
        true
      end
        
      # <li>Creates a release tag based on the working copy on your machine</li>
      # <li>Starts a new stage instance</li>
      # <li>Executes startup routines</li>
      # <li>Executes release routines</li>
      def release
        # TODO: store metadata about release with local username and hostname
        puts "Creating release from working copy"

        exit unless are_you_sure?

        tag = @scm.create_release(@global.local_user)        
        puts "Done! (#{tag})"
        
        if @option.switch
          puts "Switching working copy to new tag"
          @scm.switch_working_copy(tag)
        end
        
        @option.image ||= machine_image
        
        switch_user("root")
        
        puts "Starting an instance in #{machine_group}"
        
        instances = @ec2.instances.create(@option.image, machine_group.to_s, File.basename(keypairpath), machine_data.to_yaml, @global.zone)
        inst = instances.first
        id, state = inst[:aws_instance_id], inst[:aws_state]
        
        if @option.address ||= machine_address
          puts "Associating #{@option.address} to #{id}"
          @ec2.addresses.associate(id, @option.address)
        end
        
        wait_to_attach_disks(id)
       
        
        if @scm && @scm_params[:command]
          
          ssh do |session|
            cmd = "svn #{@scm_params[:command]} #{tag} #{@scm_params[:path]}"
            puts "Running #{cmd}"
            puts session.exec!(cmd)
          end
          
        end
        
        
        
        config = @config.machinegroup.find_deferred(@global.environment, @global.role, :config) || {}
        
        config[:global] = @global.marshal_dump
        config[:global].reject! { |n,v| n == :cert || n == :privatekey }

        tf = Tempfile.new('release-config')
        write_to_file(tf.path, config.to_hash.to_yaml, 'w')

        
        machine = @list.values.first # NOTE: we're assuming there's only one machine
        
        rscripts = @config.machinegroup.find_deferred(@global.environment, @global.role, :release, :after) || []
        rscripts = [rscripts] unless rscripts.is_a?(Array)
        rscripts.each do |rscript|
          user, script = rscript.shift
          script &&= script
          
          switch_user(user) # scp and ssh will run as this user
          
          puts "Transfering release-config.yaml..."
          scp do |scp|
            # The release-config.yaml file contains settings from ~/.rudy/config 
            scp.upload!(tf.path, "~/release-config.yaml") do |ch, name, sent, total|
              puts "#{name}: #{sent}/#{total}"
            end
          end
          ssh do |session|
            puts "Running #{script}..."
            session.exec!("chmod 700 #{script}")
            puts session.exec!("#{script}")
            
            puts "Cleaning up..."
            session.exec!("rm ~/release-config.yaml")
          end
        end
        
        
        tf.delete    # remove release-config.yaml
        
        switch_user # return to the requested user
      end
      
      
      def find_scm
        env, rol, att = @global.environment, @global.role
        
        # Look for the source control engine, checking all known scm values.
        # The available one will look like [environment][role][svn]
        params = nil
        scm = nil
        SUPPORTED_SCM_NAMES.each do |v|
          scm = v
          params = @config.machinegroup.find_deferred(env, rol, :release, scm)
          break if params
        end
        if params
          klass = eval "Rudy::SCM::#{scm.to_s.upcase}"
          scm = klass.new(:base => params[:base])
        end
        
        [scm, params]
      end
      private :find_scm
      
    end
  end
end

