require File.join(File.dirname(__FILE__), 'helper')

module Rudy::Test
  class Machines < Test::Unit::TestCase
  
    def setup
      @logger = StringIO.new
      @rmach = Rudy::Machines.new(:logger => @logger)
    end
    
    def teardown
      #if @logger.is_a?(StringIO)
      #  @logger.rewind
      #  output = @logger.read
      #  puts $/, "Rudy output:".bright, output unless output.empty?
      #end
    end
    
    context "Machines in default group" do
      xshould "(01) create 1 machine" do
        stop_test @rmach.running?, "Shutdown the machines running in #{@rmach.current_machine_group}"
        
        instances = @rmach.create
        assert instances.is_a?(Array), "instances is an Array"
        assert instances.first.is_a?(Rudy::AWS::EC2::Instance), "instance is a Rudy::AWS::EC2::Instance"
        assert_equal 1, instances.size
      end
      
      
      should "(02) list 1 machine" do
        assert @rmach.running?, "No machines running"
        instances = @rmach.list
        assert instances.is_a?(Array), "instances is an Array"
        assert instances.first.is_a?(Rudy::AWS::EC2::Instance), "instance is a Rudy::AWS::EC2::Instance"
        assert_equal 1, instances.size
      end
      
      xshould "(03) terminate 1 machine" do
        assert @rmach.running?, "No machines running"
        success = @rmach.destroy
        assert success, "instance was not terminated"
      end
      
    end
    
    
    context "Machines in specified group" do
    
    
    end
    
  end
end


# assert_equal 'John Doe', @user.full_name
# assert_same_elements([:a, :b, :c], [:c, :a, :b])
# assert_contains(['a', '1'], /\d/)
# assert_contains(['a', '1'], 'a')
