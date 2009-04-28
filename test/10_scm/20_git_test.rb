
module Rudy::Test
  class Case_10_SCM
    
    def generate_rtag(username=nil)
      now = Time.now
      mon = now.mon.to_s.rjust(2, '0')
      day = now.day.to_s.rjust(2, '0')
      rev = "01"
      criteria = ['rel', now.year, mon, day, rev]
      criteria.insert(-2, username) if username
      criteria.join(Rudy::DELIM)
    end
    
    context "#{name}_20 Git" do
      setup do
        @strand = Rudy::Utils.strand
        @scm = Rudy::SCM::GIT.new({
          :path => "/tmp/git-#{@strand}"
        })
        stop_test !Rudy::SCM::GIT.working_copy?, "Not in working directory"
      end
      
      
      should "(10) know when a tag is invalid" do
        bad_tag = generate_rtag(@strand)
        assert !@scm.valid_rtag?(bad_tag), "Said bad tag was valid"
      end
      
      should "(20) generate release tag name" do
        rtag_should = generate_rtag(@strand)
        rtag = @scm.find_next_rtag(@strand)
        assert_equal rtag_should, rtag, "Bad tag"
      end
      
      should "(30) create release" do
        rtag_should = generate_rtag(@strand)
        rtag = @scm.create_release(@strand)
        assert_equal rtag_should, rtag, "Bad tag"
        assert @scm.delete_rtag(rtag), "Could not delete tag"
      end
      
      should "(31) know when a tag is valid" do
        rtag = @scm.create_release(@strand)
        assert @scm.valid_rtag?(rtag), "Said bad tag was invalid"
        assert @scm.delete_rtag(rtag), "Could not delete tag"
      end
      
      should "(40) get remote URI" do
        rtag = @scm.get_remote_uri
        assert !@scm.get_remote_uri.nil? && !@scm.get_remote_uri.empty?, "No remote URI"
      end
      
      xshould "(90) raises exception when deleting a nonexistent tag" do
        
      end
    end
    
    
  end
end