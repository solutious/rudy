

module Rudy
  module CLI
    class Status < Rudy::CLI::CommandBase

      def status
        process_region @@global.region
        oregions = Rudy::AWS::VALID_REGIONS - [@@global.region.to_sym]
        if @option.all
          oregions.each do |region| 
            Rudy::AWS::EC2.connect @@global.accesskey, @@global.secretkey, region
            process_region region
          end
        else
          puts $/, "Other regions: " << oregions.join(', ')
        end
      end
      
      
      private 
      def process_region(region)
        puts " Region: %s %30s".att(:reverse) % [region, '']
        puts "  Instances".bright
        istatus = @option.all ? :any : :running
        (Rudy::AWS::EC2::Instances.list(istatus) || []).collect do |inst| 
          puts "    %s: %s; %s; %s" % [inst.awsid, inst.dns_public, inst.size, inst.created]
        end
        
        puts "  Volumes".bright
        (Rudy::AWS::EC2::Volumes.list || []).collect do |vol|
          puts "    %s: %sGB; %s (%s); %s" % [vol.awsid, vol.size, vol.status, vol.instid, vol.created]
        end
                
        puts "  Snapshots".bright
        (Rudy::AWS::EC2::Snapshots.list || []).collect do |snap|
          puts "    %s: %s; %s" % [snap.awsid, snap.volid, snap.created]
        end
        
        puts "  Addresses".bright
        puts (Rudy::AWS::EC2::Addresses.list || []).collect { |o| "    #{o.address}" }
        
        puts "  Groups".bright
        puts Rudy::AWS::EC2::Groups.list.collect { |o| "    #{o.name}" }
        
        puts "  Keypairs".bright
        puts Rudy::AWS::EC2::Keypairs.list.collect { |o| "    #{o.name}" }

        puts "  Images".bright
        (Rudy::AWS::EC2::Images.list('self') || []).collect do |o|
          puts "    %s: %s; %s; %s" % [o.awsid, o.location, o.arch, o.visibility]
        end
        puts
      end
      
    end
  end
end