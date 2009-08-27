

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
          li $/, "Other regions: " << oregions.join(', ')
        end
      end
      
      
      private 
      def process_region(region)
        li " Region: %s %30s".att(:reverse) % [region, '']
        li "  Machines".bright
        
        (get_machines(:region => region) rescue []).collect do |m| 
          m.refresh!
          li "    " << m.to_s.noatt
        end
        
        li "  Disks".bright
        (get_disks(:region => region) || []).collect do |d|
          d.refresh!
          li "    " << d.to_s.noatt
        end
                
        li "  Backups".bright
        (get_backups(:region => region) || []).collect do |b|
          b.refresh!
          li "    " << b.to_s.noatt
        end
        
        li
      end
      
    end
  end
end