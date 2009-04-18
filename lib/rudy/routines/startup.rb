

module Rudy; module Routines;

  class Startup < Rudy::Routines::Base
    
    def execute
      rmach = Rudy::Machines.new
      
      routine = fetch_routine_config(:startup)
      
      rbox_local = Rye::Box.new('localhost')
      Rudy::Routines::ScriptHelper.before_local(routine, rbox_local)
      Rudy::Routines::ScriptHelper.before(routine, rbox_local)
      
      #rmach.create do |machine|
      rmach.list do |machine|
      
        isup = Rudy::Utils.waiter(2, 60, STDOUT, "It's up!", nil) { 
          machine.update
          machine.dns_public? && Rudy::Utils.service_available?(machine.dns_public, 22)
        }
        
        opts = { :keys =>  root_keypairpath, :user => 'root', :debug => nil }
        rbox = Rye::Box.new(machine.dns_public, opts)
        
        Rudy::Routines::DiskHelper.execute(routine, machine, rbox)
        
        Rudy::Routines::ScriptHelper.after_local(routine, machine, rbox)
        Rudy::Routines::ScriptHelper.after(routine, machine, rbox)
        
        puts $/, "Filesystem on #{machine.name}:"
        puts rbox.df(:h)
      end
      
    end

  end

end; end