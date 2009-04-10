
module Rudy; module AWS
  class EC2
    @@logger = StringIO.new

    attr_reader :instances
    attr_reader :images
    attr_reader :addresses
    attr_reader :groups
    attr_reader :volumes
    attr_reader :snapshots
    attr_reader :aws
    attr_reader :keypairs

    def initialize(access_key, secret_key)
      ec2 = ::EC2::Base.new(:access_key_id => access_key, :secret_access_key => secret_key)
      @instances = Rudy::AWS::EC2::Instances.new(ec2)
      @images = Rudy::AWS::EC2::Images.new(ec2)
      @groups = Rudy::AWS::EC2::Groups.new(ec2)
      @addresses = Rudy::AWS::EC2::Addresses.new(ec2)
      @snapshots = Rudy::AWS::EC2::Snapshots.new(ec2)
      @volumes = Rudy::AWS::EC2::Volumes.new(ec2)
      @keypairs = Rudy::AWS::EC2::KeyPairs.new(ec2)
    end
  
  end
  
end; end