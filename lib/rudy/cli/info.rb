

module Rudy
  module CLI
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
          puts $/, "Other regions: " << oregions.join(', ')
        end
      end
      
      
      private 
      def process_region(region)
        puts " Region: %s %30s".att(:reverse) % [region, '']
        puts "  Machines".bright
        
        (get_machines(:region => region) rescue []).collect do |m| 
          m.refresh!
          puts "    " << m.to_s.noatt
        end
        
        puts "  Disks".bright
        (get_disks(:region => region) || []).collect do |d|
          d.refresh!
          puts "    " << d.to_s.noatt
        end
                
        puts "  Backups".bright
        (get_backups(:region => region) || []).collect do |b|
          b.refresh!
          puts "    " << b.to_s.noatt
        end
        
        puts
      end
      
    end
  end
end