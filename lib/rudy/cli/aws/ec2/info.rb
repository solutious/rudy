

module Rudy; module CLI
module AWS; module EC2;

  class Info < Rudy::CLI::CommandBase

    def info
      process_region @@global.region
      oregions = Rudy::AWS::VALID_REGIONS - [@@global.region.to_sym]
      if @option.all
        oregions.each do |region| 
          Rudy::AWS::EC2.connect @@global.accesskey, @@global.secretkey, region
          process_region region
        end
      else
        li $/, "Other regions: " << oregions.join(', ')
      end
    end
    
    
    private 
    def process_region(region)
      li " Region: %s %30s".att(:reverse) % [region, '']
      li "  Instances".bright
      istatus = @option.all ? :any : :running
      (Rudy::AWS::EC2::Instances.list(istatus) || []).collect do |inst| 
        #li "    %s (%s): %s; %s; %s" % [inst.awsid, inst.state, inst.dns_public || '[no dns]', inst.size, inst.created]
        li "    #{inst.to_s.noatt}"
      end
      
      li "  Volumes".bright
      (Rudy::AWS::EC2::Volumes.list || []).collect do |vol|
        li "    %s (%s): %sGB; %s" % [vol.awsid, vol.instid || vol.status, vol.size, vol.created]
      end
              
      li "  Snapshots".bright
      (Rudy::AWS::EC2::Snapshots.list || []).collect do |snap|
        li "    %s: %s; %s" % [snap.awsid, snap.volid, snap.created]
      end
      
      li "  Addresses".bright
      (Rudy::AWS::EC2::Addresses.list || []).collect do |o| 
        li "    %s (%s)" % [o.ipaddress, o.instid || 'available']
      end
      
      li "  Groups".bright
      li (Rudy::AWS::EC2::Groups.list || []).collect { |o| "    #{o.name}" }
      
      li "  Keypairs".bright
      li (Rudy::AWS::EC2::Keypairs.list || []).collect { |o| "    #{o.name}" }

      li "  Images".bright
      (Rudy::AWS::EC2::Images.list('self') || []).collect do |o|
        li "    %s: %s; %s; %s" % [o.awsid, o.location, o.arch, o.visibility]
      end
      li
    end
    
  end
  
end; end
end; end