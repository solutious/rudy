

module Rudy
  module Routines
    class Base
      include Rudy::Huxtable
    
      def initialize
        a, s, r = @@global.accesskey, @@global.secretkey, @@global.region
        @sdb = Rudy::AWS::SDB.new(a, s, r)
        @rinst = Rudy::AWS::EC2::Instances.new(a, s, r)
        @rgrp = Rudy::AWS::EC2::Groups.new(a, s, r)
        @rkey = Rudy::AWS::EC2::KeyPairs.new(a, s, r)
        @rvol = Rudy::AWS::EC2::Volumes.new(a, s, r)
        @rsnap = Rudy::AWS::EC2::Snapshots.new(a, s, r)
        init
      end
      
      def init
      end
      

      def execute
        raise "Override execute method"
      end
      
      
      def task_separator(title)
        dashes = 40 - title.size
        ("%s-- %s %s" % [$/, title, '-'*dashes]).bright
      end


    end
    
  end
end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'routines', 'helpers', '*.rb')
Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'routines', '*.rb')


