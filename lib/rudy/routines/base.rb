
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
      @@sdb ||= Rudy::AWS::SDB.new(a, s, r)
      
      # Grab the routines configuration for this routine name
      # e.g. startup, sysupdate, installdeps
      @routine = fetch_routine_config @name 
      
      ld "Routine: #{@routine.inspect}"
      
      if @routine
        # Removes the dependencies from the routines hash. 
        # We run these separately from the other actions.
        @before, @after = @routine.delete(:before), @routine.delete(:after)
      end
      
      # Share one Rye::Box instance for localhost across all routines
      @@lbox = create_rye_box @@global.localhost unless defined?(@@lbox)
      
      disable_run if @@global.testrun
      
      # We create these frozen globals for the benefit of 
      # the local and remote routine blocks. 
      $global = @@global.dup.freeze unless $global
      $option = option.dup.freeze unless $option
      ## TODO: get the machine config for just the current machine group. This
      ## probably requires Caesars to be aware of which nodes are structural.  
      ##$config = fetch_machine_config unless $config
      
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
      ld [:hostname, hostname, opts, caller[0]]
      opts = {
        :info => (@@global.verbose >= 3),  # rudy -vvv 
        :debug => false,
        :user => Rudy.sysinfo.user
      }.merge opts
      
      box = Rye::Box.new hostname, opts
      
    
      # We define hooks so we can still print each command and its output
      # when running the command blocks. NOTE: We only print this in
      # verbosity mode. 
      if @@global.verbose > 0
        # This block gets called for every command method call.
        box.pre_command_hook do |cmd, user, host, nickname|
          print_command user, nickname, cmd
        end
      end
    
      if @@global.verbose > 1
        # And this one gets called after each command method call.
        box.post_command_hook do |ret|
          print_response ret
        end
      end
      
      box.exception_hook(Rye::CommandError, &rbox_exception_handler)
      box.exception_hook(Exception, &rbox_exception_handler)
      
      ## It'd better for unknown commands to be handled elsewhere
      ## because it doesn't make sense to retry a method that doesn't exist
      ##box.exception_hook(Rye::CommandNotFound, &rbox_exception_handler)
    
      box
    end
    

    
    # Create an instance of Rye::Set from a list of +hostnames+.
    # +hostnames+ can contain hostnames or Rudy::Machine objects.
    # +opts+ is an optional Hash of options. See Rye::Box.initialize
    #
    # NOTE: Windows machines are skipped and not added to the set. 
    def create_rye_set(hostnames, opts={})
      hostnames ||= []
      
      opts = {
        :user => (current_machine_user).to_s,
        :parallel => @@global.parallel
      }.merge(opts)
      set = Rye::Set.new current_machine_group, opts 
      
      opts.delete(:parallel)   # Not used by Rye::Box.new
      
      hostnames.each do |m| 
        # This is a short-circuit for Windows instances. We don't support
        # disks for windows yet and there's no SSH so routines are out of
        # the picture too. 
        next if (m.os || '').to_s == 'win32'
          
        if m.is_a?(Rudy::Machine)
          m.refresh if m.dns_public.nil? || m.dns_public.empty?
          if m.dns_public.nil? || m.dns_public.empty?
            ld "Cannot find public DNS for #{m.name} (continuing...)"
            ##next
          end
          ld [:dns_public, m.dns_public, m.instid]
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
      
      ld "Machines Set: %s" % [set.empty? ? '[empty]' : set.inspect]
      
      set
    end
    
    

    
    # Returns a formatted string for printing command info
    def print_command(user, host, cmd)
      #return if @@global.parallel
      cmd ||= ""
      cmd, user = cmd.to_s, user.to_s
      prompt = user == "root" ? "#" : "$"
      li ("%s@%s%s %s" % [user, host, prompt, cmd.bright])
    end
    
    def print_response(rap)
      # Non zero exit codes raise exceptions so  
      # the erorrs have already been handled. 
      return if rap.exit_code != 0
      
      if @@global.parallel
        cmd, user = cmd.to_s, user.to_s
        prompt = user == "root" ? "#" : "$"
        li "%s@%s%s %s%s%s" % [rap.box.user, rap.box.nickname, prompt, rap.cmd.bright, $/, rap.stdout.inspect]
        unless rap.stderr.empty?
          le "#{rap.box.nickname}: " << rap.stderr.join("#{rap.box.nickname}: ")
        end
      else
        li '  ' << rap.stdout.join("#{$/}  ") if !rap.stdout.empty?
        colour = rap.exit_code != 0 ? :red : :normal
        unless rap.stderr.empty?
          le ("  STDERR  " << '-'*38).color(colour).bright
          le "  " << rap.stderr.join("#{$/}    ").color(colour)
        end
      end
    end
    
  private 
    
    def rbox_exception_handler
      Proc.new do |ex, cmd, user, host, nickname|
        print_exception(user, host, cmd, nickname, ex)
        unless @@global.parallel
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
    
    def print_exception(user, host, cmd, nickname, ex)
      prefix = @@global.parallel ? "#{nickname}: #{cmd}: " : ""
      if ex.is_a?(Rye::CommandError)
        le prefix << ex.message.color(:red)
      else
        le prefix << "#{ex.class}: #{ex.message}".color(:red)
      end
      le *ex.backtrace
    end
    
  end
  
end; end;