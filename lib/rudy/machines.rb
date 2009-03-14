

module Rudy
  module Huxtable
    attr_accessor :config
    attr_accessor :routines
    
    def initialize(args={})
      args = { :config => {}, :logger => STDERR }.merge(args)
      @config = args[:config]
      @logger = args[:logger]
      @routines = Rudy::Routines.new(:config => config, :logger => @logger)
    end
  end
  
  class Machines
    include Huxtable
    
    
    def shutdown(opts={})
      opts = { :group => nil, :id => nil }.merge(opts)
      raise "You must supply either a group name or instance ID" unless opts[:group] || opts[:id]
      opts[:id] = [opts[:id]] if opts[:id] && opts[:id].is_a?(Array)
      
      script_config = @config.routines.find_deferred(@global.environment, @global.role, :config) || {}        
      script_config[:global] = @global.marshal_dump
      script_config[:global].reject! { |n,v| n == :cert || n == :privatekey }
             
      
      @list = opts[:group] ? @ec2.instances.list_by_group(opts[:group]) : @ec2.instances.list(opts[:id])
      raise "No machines running in #{@option.group}" unless @list && !@list.empty?
      
      
      machines = @list.collect { |id,inst| inst }
      
      before_scripts = @config.routines.find_deferred(@global.environment, @global.role, :shutdown, :before) || []
      after_scripts = @config.routines.find_deferred(@global.environment, @global.role, :shutdown, :after) || []
      
      #@routines.execute(before_scripts, machines)
      
      
      
      #@routines.execute(after_scripts, machines)
    end
       
  end
end