
require 'date'

module Rudy
  module SCM
    class SVN
      attr_accessor :base_uri
      
      attr_reader :changes
      
      def initialize(args={})
        args = {
          :privatekey => nil,
          :base_uri => nil,
          :user => :root,
          :changes => :enforce,
          :path => nil
        }.merge(args)
        @base_uri, @path = args[:base_uri], args[:path]
        @user, @pkey, @changes = args[:user], args[:privatekey], args[:changes]
      end
      
      def engine; :svn; end
      
      def liner_note
        "%-40s  (svn:%s:%s)" % [@rtag, @base_uri, @branch]
      end
      
      def create_release(username=nil, msg=nil)
        local_uri, local_revision = local_info
        rtag = find_next_rtag(username)
        release_uri = "#{@base_uri}/#{rtag}"
        msg ||= 'Another Release by Rudy!'
        msg.tr!("'", "\\'")
        cmd = "svn copy -m '#{msg}' #{local_uri} #{release_uri}"
        
        `#{cmd} 2>&1`
        
        release_uri
      end
      
      def switch_working_copy(tag)
        raise "Invalid release tag (#{tag})." unless valid_rtag?(tag)
        `svn switch #{tag}`
      end
      
      # rel-2009-03-05-user-rev
      def find_next_rtag(username=nil)
        now = Time.now
        mon = now.mon.to_s.rjust(2, '0')
        day = now.day.to_s.rjust(2, '0')
        rev = "01"
        criteria = ['rel', now.year, mon, day, rev]
        criteria.insert(-2, username) if username
        tag = criteria.join(Rudy::DELIM)
        # Keep incrementing the revision number until we find the next one.
        tag.succ! while (valid_rtag?("#{@base_uri}/#{tag}"))
        tag
      end
      
      def local_info
        ret = Rye.shell(:svn, "info").join
        # URL: http://some/uri/path
        # Repository Root: http://some/uri
        # Repository UUID: c5abe49d-53e4-4ea3-9314-89e1e25aa7e1
        # Revision: 921
        ret.scan(/URL: (http:.+?)\s*\n.+Revision: (\d+)/m).flatten
      end
      
      def working_copy?(path)
        (File.exists?(File.join(path, '.svn')))
      end
      
      def valid_rtag?(uri)
        ret = `svn info #{uri} 2>&1` || '' # Valid SVN URIs will return some info
        (ret =~ /Repository UUID/) ? true : false
      end
      
      # Are all local changes committed?
      def self.clean_working_copy?(path=Dir.pwd)
        Rye.shell(:svn, 'diff', '.').stdout == []
      end
      def clean_working_copy?; SVN.clean_working_copy?; end
      
      def self.working_copy?(path=Dir.pwd)
        (File.exists?(File.join(path, '.svn')))
      end
      def working_copy?; SVN.working_copy?; end
      
      
      def raise_early_exceptions
        raise NotAWorkingCopy, :svn unless working_copy?
        raise DirtyWorkingCopy, :svn unless @changes.to_s == 'ignore' || clean_working_copy?
        #raise NoRemoteURI, "remote.#{@remote}.url not set" if get_remote_uri.nil?
        raise NoRemotePath, :svn if @path.nil?
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