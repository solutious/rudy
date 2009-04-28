
require 'date'

  
module Rudy
  module SCM
    class GIT
      require 'grit'
      include Rudy::SCM::ObjectBase
      include Grit
      
      attr_accessor :base_uri
      attr_accessor :remote
      attr_accessor :branch
      attr_reader :repo
      attr_reader :rbox
      attr_reader :rtag
      attr_reader :user
      attr_reader :pkey
      
      # * +args+ a hash of params from the git block in the routines config
      # 
      def initialize(args={})
        args = {
          :privatekey => nil,
          :remote => :origin,
          :branch => :master,
          :user => :root,
          :path => nil
        }.merge(args)
        @remote, @branch, @path = args[:remote], args[:branch], args[:path]
        @user, @pkey = args[:user], args[:privatekey]
        @repo = Repo.new(Dir.pwd) if GIT.working_copy?
      end
      
      def engine; :git; end
      
      def liner_note
        "%-40s  (git:%s)" % [@rtag, @branch]
      end
      
      def create_release(username=nil, msg=nil)
        @rtag = find_next_rtag(username)
        msg ||= 'Another Release by Rudy!'
        msg.tr!("'", "''")
        ret = Rye.shell(:git, "tag", @rtag)  # Use annotated? -a -m '#{msg}' 
        raise ret.stderr.join($/) if ret.exit_code > 0
        ret = Rye.shell(:git, "push #{@remote} #{rtag}") if @remote
        raise ret.stderr.join($/) if ret.exit_code > 0
        @rtag
      end
      
      # rel-2009-03-05-user-rev
      def find_next_rtag(username=nil)
        now = Time.now
        mon = now.mon.to_s.rjust(2, '0')
        day = now.day.to_s.rjust(2, '0')
        rev = "01"
        criteria = ['rel', now.year, mon, day, rev]
        criteria.insert(-2, username) if username
        rev.succ! while valid_rtag?(criteria.join(Rudy::DELIM)) && rev.to_i < 50
        raise TooManyTags if rev.to_i >= 50
        criteria.join(Rudy::DELIM)
      end
      
      def delete_rtag(rtag=nil)
        rtag ||= @rtag
        ret = Rye.shell(:git, 'tag', :d, rtag)  
        raise ret.stderr.join($/) if ret.exit_code > 0 # TODO: retest
        # "git push origin :tag-name" deletes a remote tag
        ret = Rye.shell(:git, "push #{@remote} :#{rtag}") if @remote
        raise ret.stderr.join($/) if ret.exit_code > 0
        true
      end
      
      def create_remote_checkout(rbox)
        
        # Make sure the directory above the clone path exists 
        # and that it's owned by the request user. 
        rbox.mkdir(:p, File.dirname(@path))
        rbox.chown(@user, File.dirname(@path))
        
        begin
          original_user = rbox.user
          rbox.switch_user(@user)
          
          if @pkey
            # Try when debugging: ssh -vi path/2/pkey git@github.com
            key = File.basename(@pkey)
            homedir = rbox.getenv['HOME']
            rbox.mkdir(:p, :m, '700', '.ssh') # :p says keep quiet if it exists
            if rbox.file_exists?(".ssh/#{key}")
              puts "Remote private key #{key} already exists".colour(:red)
            else
              rbox.upload(@pkey, ".ssh/#{key}") # The trailing slash is important
            end
            
            
            # This runs fine, but "git clone" doesn't care. 
            # git config --global --replace-all http.sslKey /home/delano/.ssh/id_rsa
            #rbox.git('config', '--global', '--replace-all', 'http.sslKey', "#{homedir}/.ssh/#{key}")
            
            # "git clone" doesn't care about this either. Note that both these
            # config attempts come directly from the git-config man page:
            # http://www.kernel.org/pub/software/scm/git/docs/git-config.html
            # export GIT_SSL_KEY=/home/delano/.ssh/id_rsa
            #rbox.setenv("GIT_SSL_KEY", "#{homedir}/.ssh/#{key}")
            
            if rbox.file_exists?('.ssh/config')
              rbox.cp('.ssh/config', ".ssh/config-previous")
              ssh_config = rbox.download('.ssh/config')
            end
            ssh_config ||= StringIO.new
            ssh_config.puts $/, "IdentityFile #{homedir}/.ssh/#{key}"
            puts "Adding IdentityFile #{key} to #{homedir}/.ssh/config"
            rbox.upload(ssh_config, '.ssh/config')
            rbox.chmod('0600', '.ssh/config')
          end
          
          # We need to add the host keys to the user's known_hosts file
          # to prevent the git commands from failing when it raises the
          # "Host key verification failed." messsage.
          if rbox.file_exists?('.ssh/known_hosts')
            rbox.cp('.ssh/known_hosts', ".ssh/known_hosts-previous")
            known_hosts = rbox.download('.ssh/known_hosts')
          end
          known_hosts ||= StringIO.new
          remote = get_remote_uri
          host = URI.parse(remote).host rescue nil
          host ||= remote.scan(/\A.+?@(.+?)\:/).flatten.first
          known_hosts.puts $/, Rye.remote_host_keys(host)
          puts "Adding host key for #{host} to .ssh/known_hosts"
          rbox.upload(known_hosts, '.ssh/known_hosts')
          rbox.chmod('0600', '.ssh/known_hosts')
          
          execute_rbox_command {
            rbox.git('clone', get_remote_uri, @path)
          }
          rbox.cd(@path)
          execute_rbox_command {
            rbox.git('checkout', :b, @rtag)
          }
        rescue Rye::CommandError => ex
          puts ex.message
        ensure
          # Return to the original user and directory
          rbox.switch_user(original_user)
          rbox.cd
        end
        
      end
      
      
      def get_remote_uri
        ret = Rye.shell(:git, "config", "remote.#{@remote}.url")
        ret.stdout.first
      end
      
      # Check if the given remote is valid. 
      #def has_remote?(remote)
      #  success = false
      #  (@repo.remotes || []).each do |r|
      #  end
      #  success
      #end
      
      def valid_rtag?(tag)
        # git tag -l tagname returns a 0 exit code and stdout is empty
        # when a tag does not exit. When it does exist, the exit code
        # is 0 and stdout contains the tagname. 
        ret = Rye.shell(:git, 'tag', :l, tag)  
        # change :l to :d for quick deleting above and return true
        # OR: just change to :d to always recreate the same tag
        (ret.exit_code == 0 && ret.stdout.to_s == tag)
      end
      
      # Are all local changes committed?
      def self.clean_working_copy?(path=Dir.pwd)
        Rye.shell(:git, 'diff').stdout == []
      end
      def clean_working_copy?; GIT.clean_working_copy?; end
      
      def self.working_copy?(path=Dir.pwd)
        (File.exists?(File.join(path, '.git')))
      end
      def working_copy?; GIT.working_copy?; end
      
      def raise_early_exceptions
        raise NotAWorkingCopy, :git unless working_copy?
        #raise DirtyWorkingCopy, :git unless clean_working_copy?
        raise NoRemoteURI, "remote.#{@remote}.url not set" if get_remote_uri.nil?
        raise NoRemotePath, :git if @path.nil?
        raise PrivateKeyNotFound, @pkey if @pkey && !File.exists?(@pkey)
        find_next_rtag # will raise exception is there's a problem
        
        # We can't check stuff that requires access to the machine b/c the 
        # machine may not be running yet. These include:
        # * Remote checkout path already exists
        # * No git available
        # ...
        # If create_remote_checkout should fail, it should print a message
        # about the release that was created and how to install it manually
      end
    end
  end
end