

module Rudy
  module Command
    class Release < Rudy::Command::Base
      
      def release_valid?
        raise "No SCM defined. Set RUDY_SVN_BASE or RUDY_GIT_BASE." unless @scm
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user}!" unless has_keypair?
        raise "No SSH key provided for root!" unless has_keypair?(:root)
        
        @list = @ec2.instances.list(machine_group)
        #raise "Please start an instance in #{machine_group} before releasing! (rudy -e stage instances --start)" if @list.empty?
        puts "TODO: check running instances"
        exit unless are_you_sure?
        
        true
      end
        
      def release
        
        # TODO: store metadata about release with local username and hostname
        puts "Creating release from working copy"
        tag = @scm.create_release(@global.user)
        puts "Done! (#{tag})"
        if @option.switch
          puts "Switching working copy to new tag"
          @scm.switch_working_copy(tag)
        end
        #tag = "http://rilli.unfuddle.com/svn/rilli_rilli/tags/rel-2009-03-05-rudy-921"
        machine = @list.values.first # NOTE: we're assuming there's only one machine
        
        
        rscripts = @config.machinegroup.find_deferred(@global.environment, @global.role, :release, :script) || []
        rscripts.each do |rscript|
          user, script = rscript.shift
          script_basename = File.basename(script)
          switch_user(user)
          puts "Running #{script_basename}..."
          scp_command machine[:dns_name], keypairpath, user, script, "~/"
          ssh_command machine[:dns_name], keypairpath, user, "chmod 755 ~/#{script_basename} && ~/#{script_basename} #{tag}"
        end

      end
      
    end
  end
end

