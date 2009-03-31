
module Rudy::Test
  class Case_50_Commands
    

    context "#{name}_10 KeyPairs" do
      setup do
        @rkey = Rudy::KeyPairs.new(:logger => @@logger)
        stop_test !@rkey.is_a?(Rudy::KeyPairs), "We need Rudy::KeyPairs (#{@rkey})"
      end
      
      teardown do
        #if @@logger && @@logger.is_a?(StringIO)
        #  @@logger.rewind
        #  puts @@logger.read
        #end
      end
      
      should "(10) create a keypair" do
        stop_test @rkey.any?, "Delete existing KeyPairs"
        kp = @rkey.create
        assert kp.is_a?(Rudy::AWS::EC2::KeyPair)
        assert File.exists?(@rkey.path), "No private key: #{@rkey.path}"
        assert File.exists?(@rkey.public_path), "No public key: #{@rkey.public_path}"
        assert @rkey.exists?(kp.name), "KeyPair not registered with Amazon"
      end
      
      should "(20) list keypairs" do
        assert @rkey.any?, "No keypairs"
        assert @rkey.exists?, "No #{@rkey.name} keypair"
        
        kp_list = @rkey.list
        assert kp_list.is_a?(Array), "List not an Array"
        
        kp_hash = @rkey.list_as_hash
        assert kp_hash.is_a?(Hash), "List not a Hash"
      end
      
      should "(30) not create keypair if one exists" do
        assert @rkey.exists?, "No #{@rkey.name} KeyPair"
        begin
          kp = @rkey.create
        rescue # Quiet, you!
        end
        assert kp.nil?, "Keypair was still created"
      end
      
      should "(99) destroy keypairs" do
        assert @rkey.exists?, "KeyPair #{@rkey.name} doesn't exist"
        assert @rkey.destroy, "Did not destroy #{@rkey.name}"
        assert !File.exists?(@rkey.path), "Still exists: #{@rkey.path}"
        assert !File.exists?(@rkey.public_path), "Still exists: #{@rkey.public_path}"
      end
      
      
    end
  
  
  end
end
