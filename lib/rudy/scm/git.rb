
require 'date'
require 'grit'
  
module Rudy
  module SCM
    class NotAWorkingCopy < Rudy::Error
      def message
        "You must be in the main directory of your working copy"
      end
    end
    class RemoteError < Rudy::Error; end
    class NoRemoteURI < Rudy::Error; end
    class TooManyTags < Rudy::Error
      def message; "Too many tag creation attempts!"; end
    end
    class NoRemotePath < Rudy::Error
      def message 
        "Add a path for #{@obj} in your routines config"
      end
    end
    
    class GIT
      include Grit
      
      attr_accessor :base_uri
      attr_reader :repo, :rbox
      attr_accessor :remote
      attr_accessor :branch
      attr_reader :rtag
      
      # * +args+ a hash of params from the git block in the routines config
      # 
      def initialize(args={})
        args = {
          :remote => :origin,
          :branch => :master,
          :path => nil
        }.merge(args)
        @remote, @branch, @path = args[:remote], args[:branch], args[:path]
        raise NoRemotePath, :git if @path.nil?
        @repo = Repo.new(Dir.pwd) if GIT.working_copy?
      end
      
      def create_release(username=nil, msg=nil)
        @rtag = generate_rtag(username)
        msg ||= 'Another Release by Rudy!'
        msg.tr!("'", "''")
        ret = Rye.shell(:git, "tag", @rtag)  # Use annotated? -a -m '#{msg}' 
        raise ret.stderr.join($/) if ret.exit_code > 0
        ret = Rye.shell(:git, "push #{@remote} #{rtag}") if @remote
        raise ret.stderr.join($/) if ret.exit_code > 0
        @rtag
      end
      
      # rel-2009-03-05-user-rev
      def generate_rtag(username=nil)
        now = Time.now
        mon = now.mon.to_s.rjust(2, '0')
        day = now.day.to_s.rjust(2, '0')
        rev = "01"
        criteria = ['rel', now.year, mon, day, rev]
        criteria.insert(-2, username) if username
        rev.succ! while valid_rtag?(criteria.join(Rudy::DELIM)) && rev.to_i < 100
        raise TooManyTags if rev.to_i >= 100
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
        raise RemoteError, "#{@path} exists" if rbox.file_exists?(@path)
        begin
          puts "  "
          rbox.git('clone', get_remote_uri, @path)
          rbox.git('checkout', @rtag)
        rescue Rye::CommandError => ex
          puts ex.message
        end
        
      end
      
      
      def get_remote_uri
        ret = Rye.shell(:git, "config", "remote.#{@remote}.url")
        unless ret.exit_code == 0 && !ret.stdout.empty?
          raise NoRemoteURI, "remote.#{@remote}.url not set"
        end
        ret.stdout.first
      end
      
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
        raise NotAWorkingCopy, path unless working_copy?(path)
        Rye.shell(:git, 'diff').stdout == []
      end
      
      def self.working_copy?(path=Dir.pwd)
        (File.exists?(File.join(path, '.git')))
      end
      
    end
  end
end