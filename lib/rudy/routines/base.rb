
module Rudy; module Routines;
  class Base
    include Rudy::Huxtable
    
    @@run = true
    
    def self.run?; @@run; end
    def self.disable_run; @@run = false; end
    def self.enable_run; @@run = true; end
    
    def run?; @@run; end
    def disable_run; @@run = false; end
    def enable_run; @@run = true; end
    
      # The Rye::Box instance used for all local actions
    attr_reader :lbox
      # An Array Rudy::Machines objects that will be processed
    attr_reader :machines
    
    # * +name+ The name of the command specified on the command line
    # * +option+ A Hash or OpenStruct of named command line options. 
    #   If it's a Hash it will be converted to an OpenStruct.
    # * +argv+ An Array of arguments
    #
    # +option+ and +argv+ are made available to the routine block. 
    # 
    #     routines do
    #       magic do |options,argv|
    #         ...
    #       end
    #     end
    #
    def initialize(name=nil, option={}, argv=[], *args)
      name ||= (self.class.to_s.split(/::/)).last.downcase
      option = OpenStruct.new(option) if option.is_a? Hash
      @name, @option, @argv = name.to_sym, option, argv
      a, s, r = @@global.accesskey, @@global.secretkey, @@global.region
      @sdb = Rudy::AWS::SDB.new(a, s, r)
      @rinst = Rudy::AWS::EC2::Instances.new(a, s, r)
      @rgrp = Rudy::AWS::EC2::Groups.new(a, s, r)
      @rkey = Rudy::AWS::EC2::KeyPairs.new(a, s, r)
      @rvol = Rudy::AWS::EC2::Volumes.new(a, s, r)
      @rsnap = Rudy::AWS::EC2::Snapshots.new(a, s, r)
      
      @rmach = Rudy::Machines.new
      
      local_rye_opts = {
        :info => (@@global.verbose > 3), 
        :debug => false
      }
      
      @lbox = Rye::Box.new @@global.localhost, local_rye_opts
      @machines = @rmach.list unless @@global.offline
      @machines ||= []
      
      init(*args)
    end
    
                      def init; raise "Please override"; end
                   def execute; raise "Please override"; end
    def raise_early_exceptions; raise "Please override"; end    
    
    def machine_separator(name, awsid)
      ('%s %-50s awsid: %s ' % [$/, name, awsid]).att(:reverse)
    end
    
    def enjoy_every_sandwich(ret=nil, &bloc_party)
      begin
        ret = bloc_party.call
      rescue => ex
        STDERR.puts "  Error: #{ex.message}".color(:red)
        STDERR.puts ex.backtrace if Rudy.debug?
        choice = Annoy.get_user_input('(S)kip  (R)etry  (A)bort: ') || ''
         if choice.match(/\AS/i)
           return
         elsif choice.match(/\AR/i)
           retry
         else
           exit 12
         end
      rescue Interrupt
        puts "Aborting..."
        exit 12
      end
      ret
    end
    
  end
  
end; end;