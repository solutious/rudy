
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
      
      # Grab the routines configuration for this routine name
      # e.g. startup, sysupdate, installdeps
      @routine = fetch_routine_config @name 
      
      ld "Routine: #{@routine.inspect}"
      
      @lbox = create_rye_box @@global.localhost
       
      init(*args) if respond_to? :init
    end
    
    def raise_early_exceptions; raise "Please override"; end
    def execute; raise "Please override"; end
    
    # Create an instance of Rye::Box for +hostname+. +opts+ is
    # an optional Hash of options. See Rye::Box.initialize
    #
    # This method should be used throughout the Rudy::Routines 
    # namespace rather than creating instances manually b/c it 
    # applies some fancy pants defaults like command hooks.
    def create_rye_box(hostname, opts={})
      
      opts = {
        :info => (@@global.verbose > 3),  # rudy -vvvv 
        :debug => false,
        :user => @@global.localuser
      }.merge opts
      
      box = Rye::Box.new hostname, opts
      
      
      unless @@global.parallel
      
        # We define hooks so we can still print each command and its output
        # when running the command blocks. NOTE: We only print this in
        # verbosity mode. 
        if @@global.verbose > 0
          # This block gets called for every command method call.
          box.pre_command_hook do |cmd, user, host, nickname|
            puts command_separator(cmd, user, nickname)
          end
        end
      
        if @@global.verbose > 1
          # And this one gets called after each command method call.
          box.post_command_hook do |ret|
            puts '  ' << ret.stdout.join("#{$/}  ") if !ret.stdout.empty?
            print_response ret
          end
        end
      
        box.exception_hook(Rye::CommandError, &rbox_exception_handler)
        box.exception_hook(Exception, &rbox_exception_handler)
        
        ## It'd better for unknown commands to be handled elsewhere
        ## because it doesn't make sense to retry a method that doesn't exist
        ##box.exception_hook(Rye::CommandNotFound, &rbox_exception_handler)
      end
      
      box
    end
    

    
    # Create an instance of Rye::Set from a list of +hostnames+.
    # +hostnames+ can contain hostnames or Rudy::Machine objects.
    # +opts+ is an optional Hash of options. See Rye::Box.initialize
    #
    # NOTE: Windows machines are skipped and not added to the set. 
    def create_rye_set(hostnames=[], opts={})
      opts = {
        :user => (fetch_machine_param(:user) || @@global.localuser).to_s
      }.merge(opts)
      set = Rye::Set.new current_machine_group, opts 
      
      hostnames.each do |m| 
        # This is a short-circuit for Windows instances. We don't support
        # disks for windows yet and there's no SSH so routines are out of
        # the picture too. 
        next if (m.os || '').to_s == 'win32'
          
        if m.is_a?(Rudy::Machine)
          m.update if m.dns_public.nil? || m.dns_public.empty?
          if m.dns_public.nil? || m.dns_public.empty?
            le "Cannot find public DNS for #{m.name}"
            next
          end
          rbox = create_rye_box(m.dns_public, opts) 
          rbox.stash = m   # Store the machine instance in the stash
          rbox.nickname = m.name
        else
          # Otherwise we assume it's a hostname
          rbox = create_rye_box(m)
        end
        rbox.add_key user_keypairpath(opts[:user])
        set.add_box rbox
      end
      
      if set.empty?
        ld "Machines Set: [empty]"
      else
        ld "Machines Set:"
        set.boxes.each do |b|
          ld b.inspect
        end
      end
      
      set
    end
    
    
    def generic_routine_wrapper(&routine_action)
      
      routine = @routine
      raise "No routine supplied" unless routine.kind_of?(Hash)

      # This gets and removes the dependencies from the routines hash.
      # We grab the after ones now too, so they can also be removed.
      before_deps = Rudy::Routines::DependsHelper.get(:before, routine)
      after_deps  = Rudy::Routines::DependsHelper.get(:after,  routine) 
      
      Rudy::Routines::DependsHelper.execute_all before_deps
      
      # This is the meat of the sandwich
      if routine_action && run?
        routine.each_pair { |action,defenition| 
          routine_action.call action, defenition
        }
      end
      
      Rudy::Routines::DependsHelper.execute_all after_deps
      
    end
    
    def machine_separator(name, awsid)
      ('%s %-50s awsid: %s ' % [$/, name, awsid]).att(:reverse)
    end
    
    # Returns a formatted string for printing command info
    def command_separator(cmd, user, host)
      cmd ||= ""
      cmd, user = cmd.to_s, user.to_s
      prompt = user == "root" ? "#" : "$"
      ("%s@%s%s %s" % [user, host, prompt, cmd.bright])
    end
    
    def print_response(rap)
      return if rap.exit_code != 0
      colour = rap.exit_code != 0 ? :red : :normal
      return if rap.stderr.empty?
      STDERR.puts(("  STDERR  " << '-'*38).color(colour).bright)
      STDERR.puts "  " << rap.stderr.join("#{$/}  ").color(colour)
      if rap.exit_code != 0
        STDERR.puts "  Exit code: #{rap.exit_code}".color(colour) 
      end
    end
    

    
  private 
    def enjoy_every_sandwich(ret=nil, &bloc_party)
      begin
        ret = bloc_party.call
      rescue => ex
        unless @@global.parallel
          STDERR.puts "  #{ex.class}: #{ex.message}".color(:red)
          STDERR.puts ex.backtrace if Rudy.debug?
          choice = Annoy.get_user_input('(S)kip  (A)bort: ') || ''
          if choice.match(/\AS/i)
            # do nothing
          else
            exit 12
          end
         end
      rescue Interrupt
        puts "Aborting..."
        exit 12
      end
      ret
    end
  
    def rbox_exception_handler
      Proc.new do |ex|
        if ex.is_a?(Rye::CommandError)
          STDERR.puts "  #{ex.message}".color(:red)
        else
          STDERR.puts "  #{ex.class}: #{ex.message}".color(:red)
        end
        STDERR.puts ex.backtrace if Rudy.debug?
        choice = Annoy.get_user_input('(S)kip  (R)etry  (A)bort: ') || ''
        if choice.match(/\AS/i)
          :skip
        elsif choice.match(/\AR/i)
          :retry   # Tells Rye::Box#run_command to retry
        else
          exit 12
        end
      end
    end
    
  end
  
end; end;