

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Candy < Rudy::CLI::Base
    



    def ssh
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:group] = :any if @option.all

      opts[:id] = @argv.shift if Rudy.is_id?(:instance, @argv.first)
      opts[:id] &&= [opts[:id]].flatten
      
      @option.user ||= Rudy.sysinfo.user
      
      if @argv.first
        command, command_args = [@argv.first].flatten.join(' ')
        execute_check(:medium) if @option.user == "root"
      end
      
      if @option.pkey
        raise "Cannot find file #{@option.pkey}" unless File.exists?(@option.pkey)
        raise "Insecure permissions for #{@option.pkey}" unless (File.stat(@option.pkey).mode & 600) == 0
      end
      
      rudy = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      lt = rudy.list_group(opts[:group], :running, opts[:id]) do |inst|
        puts "Connecting to: #{inst.awsid.bright} as #{@option.user.bright} (group: #{inst.groups.join(', ')})", $/
        ssh_opts = {
          #:debug => STDERR,
          :user => @option.user
        }
        ssh_opts[:keys] = @option.pkey if @option.pkey
        
        rbox = Rye::Box.new(inst.dns_public, ssh_opts)
          
        command, command_args = :interactive_ssh, @option.print.nil? unless command
        puts rbox.send(command, command_args)
        
      end
    end

    def copy_valid?
      raise "You must supply a source and a target. See rudy-ec2 #{@alias} -h" unless @argv.size >= 2
      raise "You cannot download and upload at the same time" if @option.download && @alias == 'upload'
      raise "You cannot download and upload at the same time" if @option.upload && @alias == 'download'
      true
    end
    def copy
      
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:group] = :any if @option.all

      opts[:id] = @argv.shift if Rudy.is_id?(:instance, @argv.first)
      opts[:id] &&= [opts[:id]].flatten
      
      @option.user ||= Rudy.sysinfo.user
    
      # * +:recursive: recursively transfer directories (default: false)
      # * +:preserve: preserve atimes and ctimes (default: false)
      # * +:task+ one of: :upload (default), :download.
      # * +:paths+ an array of paths to copy. The last element is the "to" path.
      opts[:recursive] = @option.recursive ? true : false
      opts[:preserve] = @option.preserve ? true : false
      
      opts[:paths] = @argv
      opts[:dest] = opts[:paths].pop
    
      opts[:task] = :download if @alias == 'download' || @option.download
      opts[:task] = :upload if @alias == 'upload'
      opts[:task] ||= :upload
    
      #exit unless @option.print || Annoy.are_you_sure?(:low)

      if @option.pkey
        raise "Cannot find file #{@option.pkey}" unless File.exists?(@option.pkey)
        raise "Insecure permissions for #{@option.pkey}" unless (File.stat(@option.pkey).mode & 600) == 0
      end


      rudy = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      lt = rudy.list_group(opts[:group], opts[:state], opts[:id]) do |inst|
        puts "Connecting to: #{inst.awsid.bright} as #{@option.user.bright} (group: #{inst.groups.join(', ')})"


        msg = opts[:task] == :upload ? "Upload to" : "Download from"
        @@logger.puts $/, "#{msg} #{inst.awsid}"

        if @option.print
          Rudy::Utils.scp_command inst.dns_public, @option.pkey, @option.user, opts[:paths], opts[:dest], (opts[:task] == :download), false, @option.print
          return
        end

        scp_opts = {
          :recursive => opts[:recursive],
          :preserve => opts[:preserve],
          :chunk_size => 16384
        }

        Rudy::Huxtable.scp(opts[:task], inst.dns_public, @option.user, @option.pkey, opts[:paths], opts[:dest], scp_opts)
        puts 
      end

    end
    
  end
  
  
end; end
end; end
