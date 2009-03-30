
module Rudy::Test
  class Commands
    
    xcontext "(80) #{name} stub" do
      should "do nothing to prevent Ruby 1.8 error message" do
        assert true
      end
    end
    
    xcontext "(80) #{name} Machines" do
      
      should "(00) have current machine group" do
        assert @@rmach.current_machine_group.is_a?(String), "No current machine group"
        assert @@rgroup.exists?(@@rmach.current_machine_group), "No matching security group"
      end
      
      should "(01) create machine group" do
        stop_test @@rmach.running?, "Shutdown the machines running in #{@rmach.current_machine_group}"
        instances = @@rmach.create
        assert instances.is_a?(Array), "instances is not an Array"
        assert instances.first.is_a?(Rudy::AWS::EC2::Instance), "instance is not a Rudy::AWS::EC2::Instance (#{instances.first.class})"
        assert_equal 1, instances.size, "#{instances.size} instances were started"
      end
      
      
      should "(02) list 1 machine" do
        assert @@rmach.running?, "No machines running"
        instances = @@rmach.list
        assert instances.is_a?(Array), "instances is not an Array"
        assert instances.first.is_a?(Rudy::AWS::EC2::Instance), "instance is not a Rudy::AWS::EC2::Instance"
        assert_equal 1, instances.size, "#{instances.size} instances are running"
      end
      
      should "(03) terminate 1 machine" do
        assert @@rmach.running?, "No machines running"
        success = @@rmach.destroy
        assert success, "instance was not terminated"
      end
      
    end
    

  end
end


# assert_equal 'John Doe', @user.full_name
# assert_same_elements([:a, :b, :c], [:c, :a, :b])
# assert_contains(['a', '1'], /\d/)
# assert_contains(['a', '1'], 'a')
