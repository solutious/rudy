


module Rudy::CLI
  class Console < Rudy::CLI::Base
    
    def console
      puts "Rudy Console (ALPHA)".bright
      puts "Warning: This console is not very useful!"
      # SEE: http://github.com/rubyspec/matzruby/blob/a34130eb7c4ecc164115a59aa1b76c643bd98202/lib/irb/xmp.rb
      # SEE: http://github.com/blackwinter/wirble/tree/master
      require "irb"

      #require 'irb/completion'
      #IRB.conf[:USE_READLINE] = true
      #
      ## Prompts
      #IRB.conf[:PROMPT] = {
      #  :CUSTOM2 => {
      #    :PROMPT_N => "> ",
      #    :PROMPT_I => "> ",
      #    :PROMPT_S => nil,
      #    :PROMPT_C => "> ",
      #    :RETURN => ""
      #  }
      #}
      #
      ## Set default prompt
      #IRB.conf[:PROMPT_MODE] = :CUSTOM2
      #
      #
      #
      #def IRB.parse_opts
      #   # Don't touch ARGV, which belongs to the app which called this module.
      #end
      #
      #def IRB.start_session(*args)
      #  unless $irb
      #    IRB.setup nil
      #    ## maybe set some opts here, as in parse_opts in irb/init.rb?
      #  end
      #  
      #  puts "HI"
      #  workspace = WorkSpace.new(*args)
      #
      #  if @CONF[:SCRIPT] ## normally, set by parse_opts
      #    $irb = Irb.new(workspace, @CONF[:SCRIPT])
      #  else
      #    $irb = Irb.new(workspace)
      #  end
      #
      #  @CONF[:IRB_RC].call($irb.context) if @CONF[:IRB_RC]
      #  @CONF[:MAIN_CONTEXT] = $irb.context
      #
      #  trap 'INT' do
      #    $irb.signal_handle
      #  end
      #
      #  custom_configuration if defined?(IRB.custom_configuration)
      #
      #  catch :IRB_EXIT do
      #    $irb.eval_input
      #  end
      #  ## might want to reset your app's interrupt handler here
      #end
      
      #puts "Rudy Console".bright
      #puts $/, "Please Note: this console is incomplete!", $/
      
      # "As an interesting twist on configuring irb, you can set IRB.conf[:IRB_RC] to a Proc object. 
      # This proc will be invoked whenever the irb context is changed, and will receive that new 
      # context as a parameter. You can use this facility to change the configuration dynamically 
      # based on the context." -- http://www.rubycentral.com/pickaxe/irb.html
      
      
      #IRB.conf[:PROMPT] = {
      #  :SIMPLE => {
      #        :PROMPT_I => "%N(%m):%03n:%i> ",
      #        :PROMPT_S => "%N(%m):%03n:%i%l ",
      #        :PROMPT_C => "%N(%m):%03n:%i* ",
      #        :RETURN => "%s#{$/}"
      #  }
      #}
      
      #p IRB.conf
      
      if __FILE__ == $0
        IRB.start(__FILE__)
      else
        # check -e option
        if /^-e$/ =~ $0
          IRB.start(__FILE__)
        else
          IRB.start(__FILE__)
        end
      end
      
    end
  
  end
end
  