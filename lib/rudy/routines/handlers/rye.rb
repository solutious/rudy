module Rudy::Routines::Handlers;
  module RyeTools
    include Rudy::Routines::Handlers::Base
    extend self


     # Create an instance of Rye::Box for +hostname+. +opts+ is
     # an optional Hash of options. See Rye::Box.initialize
     #
     # This method should be used throughout the Rudy::Routines 
     # namespace rather than creating instances manually b/c it 
     # applies some fancy pants defaults like command hooks.
     def create_box(hostname, opts={})
       ld [:hostname, hostname, opts, caller[0]]
       opts = {
         :debug => false,
         :user => current_machine_user, 
         :ostype => current_machine_os || :unix,
         :impltype => :linux, 
         :info => STDOUT,
         :paranoid => false  # doesn't get passed through (Rye bug?)
       }.merge opts
       
       nickname = hostname
       if hostname.kind_of? Rudy::Machine
         hostname, nickname = hostname.dns_public, hostname.name
       end
       
       box = ::Rye::Box.new hostname, opts
       box.nickname = nickname
      
       local_keys = Rye.keys
       box.add_keys local_keys if local_keys.is_a?(Array)
       box.add_key user_keypairpath(opts[:user])
       
       # We define hooks so we can still print each command and its output
       # when running the command blocks. NOTE: We only print this in
       # verbosity mode. 
       if !@@global.parallel && !@@global.quiet
         # This block gets called for every command method call.
         box.pre_command_hook do |cmd, user, host, nickname|
           print_command user, nickname, cmd
         end
       end

       if @@global.verbose > 0 && !@@global.quiet
         box.stdout_hook do |content|
           li content
         end
         # And this one gets called after each command method call.
         box.post_command_hook do |ret|
           print_response ret
         end
       end

       box.exception_hook(::Rye::Err, &rbox_exception_handler)
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
     def create_set(hostnames, opts={})
       hostnames ||= []
       
       ld "Creating set from:", hostnames.inspect
       
       opts = {
         :user => (current_machine_user).to_s,
         :parallel => @@global.parallel,
         :quiet => Rudy.quiet?
       }.merge(opts)
       set = ::Rye::Set.new current_machine_group, opts 
       
       opts.delete(:parallel)   # Not used by Rye::Box.new

       hostnames.each do |m| 

         if m.is_a?(Rudy::Machine)
           m.refresh! if m.dns_public.nil? || m.dns_public.empty?
           if m.dns_public.nil? || m.dns_public.empty?
             ld "Cannot find public DNS for #{m.name} (continuing...)"
             rbox = self.create_box('nohost', opts) 
           else
             ld [:dns_public, m.dns_public, m.instid]
             rbox = self.create_box(m.dns_public, opts) 
           end
           rbox.stash = m   # Store the machine instance in the stash
           rbox.nickname = m.name
         else
           # Otherwise we assume it's a hostname
           rbox = self.create_box(m)
         end
         rbox.add_key user_keypairpath(opts[:user])
         set.add_box rbox
       end

       ld "Machines Set: %s" % [set.empty? ? '[empty]' : set.inspect]

       set
     end


    private 

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
      return if rap.exit_status != 0

      if @@global.parallel
        cmd, user = cmd.to_s, user.to_s
        prompt = user == "root" ? "#" : "$"
        li "%s@%s%s %s%s%s" % [rap.box.user, rap.box.nickname, prompt, rap.cmd.bright, $/, rap.stdout.inspect]
        unless rap.stderr.empty?
          le "#{rap.box.nickname}: " << rap.stderr.join("#{rap.box.nickname}: ")
        end
      else
        colour = rap.exit_status != 0 ? :red : :normal
        unless rap.stderr.empty?
          le ("  STDERR  " << '-'*38).color(colour).bright
          le "  " << rap.stderr.join("#{$/}    ").color(colour)
        end
      end
    end


   def rbox_exception_handler
     Proc.new do |ex, cmd, user, host, nickname|
       print_exception(user, host, cmd, nickname, ex)
       unless @@global.parallel
         choice = Annoy.get_user_input('(S)kip  (R)etry  (I)nteractive  (A)bort: ', nil, 3600) || ''
         if choice.match(/\AS/i)
           :skip
         elsif choice.match(/\AR/i)
           :retry   # Tells Rye::Box#run_command to retry
         elsif choice.match(/\AI/i)
           :interactive
         else
           exit 12
         end
       end
     end
   end

   def print_exception(user, host, cmd, nickname, ex)
     prefix = @@global.parallel ? "#{nickname}: #{cmd}: " : ""
     if ex.is_a?(::Rye::Err)
       le prefix << ex.message.color(:red)
     else
       le prefix << "#{ex.class}: #{ex.message}".color(:red)
     end
     le ex.backtrace if Rudy.debug?
   end


 end
end

