
module Rudy::Test
  class Case_50_Commands
    

    context "#{name}_10 KeyPairs" do
      setup do
        @rkey = Rudy::KeyPairs.new(:logger => @@logger)
          @rgroup = Rudy::Groups.new(:logger => @@logger)
        # So we can test with and without user specified keypairs
        @rkey.global.environment = :test
        stop_test !@rkey.is_a?(Rudy::KeyPairs), "We need Rudy::KeyPairs (#{@rkey})"
      end
      
      teardown do
        #if @@logger && @@logger.is_a?(StringIO)
        #  @@logger.rewind
        #  puts @@logger.read
        #end
      end
      
      should "(10) create a keypair" do
        stop_test @rkey.any?, "Delete existing keypairs"
        kp = @rkey.create
        assert kp.is_a?(Rudy::AWS::EC2::KeyPair)
        assert File.exists?(@rkey.path), "No private key: #{@rkey.path}"
        assert File.exists?(@rkey.public_path), "No public key: #{@rkey.public_path}"
        assert @rkey.exists?(kp.name), "KeyPair not registered with Amazon"
      end
      
      should "(11) create a keypair with an arbitrary name" do
        n = "test-%s" % Rudy::Utils.strand
        kp = @rkey.create(n)
        assert kp.is_a?(Rudy::AWS::EC2::KeyPair)
        assert File.exists?(@rkey.path(n)), "No private key: #{@rkey.path(n)}"
        assert File.exists?(@rkey.public_path(n)), "No public key: #{@rkey.public_path(n)}"
        assert @rkey.exists?(kp.name), "KeyPair not registered with Amazon"
      end
      
      should "(12) not create keypair if one exists" do
        assert @rkey.exists?, "No #{@rkey.name} KeyPair"
        begin
          kp = @rkey.create
        rescue # Quiet, you!
        end
        assert kp.nil?, "Keypair was still created"
      end
      
      should "(13) not create keypair if a root keypair is defined in config" do
        @rkey.global.environment = :stage  # stage needs keypairs configured
        assert_equal @rkey.global.environment, :stage
        assert @rkey.has_root_keypair?, "No root keypair path defined in config"
        begin
          kp = @rkey.create
        rescue => ex
        end
        assert kp.nil?, "Keypair was still created"
      end
      
      should "(20) list keypairs" do
        assert @rkey.any?, "No keypairs"
        
        kp_list = @rkey.list
        assert kp_list.is_a?(Array), "List not an Array"
        
        kp_hash = @rkey.list_as_hash
        assert kp_hash.is_a?(Hash), "List not a Hash"
        
        assert kp_list.size > 1, "List not greater than 1 (#{kp_list.size})"
      end
      
      should "(30) find existing keypair for current machine group" do
        
        test_kp = @rkey.user_keypairpath(:root)
        @rkey.global.environment = :stage
        stage_kp = @rkey.user_keypairpath(:root)
        
        assert !test_kp.nil?, "Test keypair is nil"
        assert !stage_kp.nil?, "Stage keypair is nil"
        assert test_kp != stage_kp, "Test and Stage keypairs are the same (how can this be??)"
      end
      
      should "(99) destroy keypairs" do
        assert @rkey.any?, "No keypairs registered"
        @rkey.list.each do |kp|
          assert @rkey.destroy(kp.name), "Did not destroy #{kp.name}"
        end
        assert !File.exists?(@rkey.path), "Still exists: #{@rkey.path}"
        assert !File.exists?(@rkey.public_path), "Still exists: #{@rkey.public_path}"
      end
      
      
    end
  
  
  end
end
