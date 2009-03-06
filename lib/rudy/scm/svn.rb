
require 'date'

module Rudy
  module SCM
    class SVN
      attr_accessor :base_uri
      
      def initialize(args={:base => ''})
        @base_uri = args[:base]
      end
      
      def create_release(username=nil)
        raise "#{Dir.pwd} is not a working copy" unless svn_dir?(Dir.pwd)
        raise "There are local changes. Please revert or check them in." unless everything_checked_in?
        raise "Invalid base URI (#{@base_uri})." unless valid_uri?(@base_uri)
        
        local_uri, local_revision = local_info
        rtag = generate_release_tag_name(username)
        release_uri = "#{@base_uri}/#{rtag}"
        cmd = "svn copy -m 'Another Release by Rudy!' #{local_uri} #{release_uri}"
        
        #puts "disabled svn copy"
        `#{cmd} 2>&1`
        
        release_uri
      end
      
      def switch_working_copy(tag)
        raise "Invalid release tag (#{tag})." unless valid_uri?(tag)
        `svn switch #{tag}`
      end
      
      # rel-2009-03-05-user-rev
      def generate_release_tag_name(username=nil)
        now = Time.now
        mon = now.mon.to_s.rjust(2, '0')
        day = now.day.to_s.rjust(2, '0')
        rev = "r01"
        criteria = ['rel', now.year, mon, day, rev]
        criteria.insert(-2, username) if username
        tag = criteria.join(RUDY_DELIM)
        # Keep incrementing the revision number until we find the next one.
        tag.succ! while (valid_uri?("#{@base_uri}/#{tag}"))
        tag
      end
      
      def local_info
        ret = `svn info 2>&1`
        # URL: http://some/uri/path
        # Repository Root: http://some/uri
        # Repository UUID: c5abe49d-53e4-4ea3-9314-89e1e25aa7e1
        # Revision: 921
        ret.scan(/URL: (http:.+?)\s*\n.+Revision: (\d+)/m).flatten
      end
      
      def svn_dir?(path)
        (File.exists?(File.join(path, '.svn')))
      end
      
      def valid_uri?(uri)
        ret = `svn info #{uri} 2>&1` || '' # Valid SVN URIs will return some info
        (ret =~ /Repository UUID/) ? true : false
      end
      
      def everything_checked_in?
        `svn diff . 2>&1` == '' # svn diff should return nothing
      end
    end
  end
end