group "EC2"
library :rudy, 'lib'

tryouts "Groups Authorize/Revoke Account" do
  set :global, Rudy::Huxtable.global
  set :group_name, 'grp-' << Rudy::Utils.strand
  setup do
    Rudy::Huxtable.update_config
    Rudy::AWS::EC2.connect global.accesskey, global.secretkey, global.region
    Rudy::AWS::EC2::Groups.create group_name
  end
  clean do 
    Rudy::AWS::EC2::Groups.destroy group_name
  end
  
  dream :class, String
  dream :empty?, false
  drill "has account num" do
    Rudy::Huxtable.config.accounts.aws.accountnum
  end
  
  drill "authorize group rules returns true", true do
    accountnum = Rudy::Huxtable.config.accounts.aws.accountnum
    Rudy::AWS::EC2::Groups.authorize_group group_name, group_name, accountnum
  end
  
    dream :class, Rudy::AWS::EC2::Group
    dream :proc, lambda { |group|
      accountnum = Rudy::Huxtable.config.accounts.aws.accountnum
      should_have = "#{accountnum}:#{group_name}"
      return false unless group.groups.is_a?(Hash)
      group.groups.has_key?(should_have) == true
    }
  drill "group (#{group_name}) contains new rules" do
    stash :group, Rudy::AWS::EC2::Groups.get(group_name)
  end
  
  drill "revoke group rules returns true", true do
    accountnum = Rudy::Huxtable.config.accounts.aws.accountnum
    Rudy::AWS::EC2::Groups.revoke_group group_name, group_name, accountnum
  end
  
    dream :proc, lambda { |group| 
      accountnum = Rudy::Huxtable.config.accounts.aws.accountnum
      should_have = "#{accountnum}:#{group_name}"
      return false unless group.groups.is_a?(Hash)
      group.groups.has_key?(should_have) == false
    }
    drill "group (#{group_name}) does not contain new rules" do
    stash :group, Rudy::AWS::EC2::Groups.get(group_name)
  end

  
end