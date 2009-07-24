group "EC2"
library :rudy, 'lib'

tryouts "Groups" do
  set :global, Rudy::Huxtable.global
  set :group_name, 'grp-' << Rudy::Utils.strand
  set :group_desc, 'desc-' << group_name
  setup do
    Rudy::Huxtable.update_config
    Rudy::AWS::EC2.connect global.accesskey, global.secretkey, global.region
  end
  
  dream :class, Rudy::AWS::EC2::Group
  dream :name, group_name
  dream :description, "Security Group #{group_name}"
  drill "create group with name" do
    Rudy::AWS::EC2::Groups.create group_name
  end
  
  dream :class, Rudy::AWS::EC2::Group
  dream :name, "#{group_name}2"
  dream :description, group_desc
  drill "create group with name and description" do
    Rudy::AWS::EC2::Groups.create "#{group_name}2", group_desc
  end
  
  drill "list as Array", :class, Array do
    Rudy::AWS::EC2::Groups.list
  end
  
  drill "list as Hash", :class, Hash do
    Rudy::AWS::EC2::Groups.list_as_hash
  end
  
  dream :size, 1  # will equal 2 if test fails
  drill "list returns Group objects" do
    list = Rudy::AWS::EC2::Groups.list
    list.collect! do |group|
      group.is_a?(Rudy::AWS::EC2::Group)
    end
    list.uniq
  end
  
  dream :class, Array
  dream :size, 1
  drill "destroy groups" do
    list = Rudy::AWS::EC2::Groups.list
    list.collect! do |group|
      next if group.name == "default" # can't delete this default group
      Rudy::AWS::EC2::Groups.destroy group.name
    end
    Rudy::AWS::EC2::Groups.list
  end
end


