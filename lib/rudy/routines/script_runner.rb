
require 'tempfile'

module Rudy::Routines
  class ScriptRunner
    include Rudy::Routines::Base
    
    def execute(instance, routine, before_or_after)
      return false unless instance
      
      rscripts = @config.routines.find_deferred(@global.environment, @global.role, routine, before_or_after) || []
      rscripts &&= [rscripts].flatten # Make sure it's an Array
      if !rscripts || rscripts.empty?
        @logger.puts "No scripts defined."
        return
      end
      
      # The config file will contain settings from ~/.rudy/config
      script_config = @config.routines.find_deferred(@global.environment, @global.role, :config) || {}        
      script_config[:global] = @global.marshal_dump
      script_config[:global].reject! { |n,v| n == :cert || n == :privatekey }
      script_config_filename = "config.yaml"
      
      tf = Tempfile.new(script_config_filename)
      write_to_file(tf.path, script_config.to_hash.to_yaml, 'w')

      rscripts.each do |rscript|
        user, script = rscript.shift
        
        begin
          Net::SCP.start(host, user, :keys => [keypairpath(user)]) do |scp|
            scp.upload!(tf.path, "~/#{script_config_filename}") do |ch, name, sent, total|
              "#{name}: #{sent}/#{total}"
            end
          end
        rescue => ex
          raise "Error transfering #{script_config_filename}: #{ex.message} "
        end
        
        begin
          Net::SSH.start(instance.dns_name_public, user, :keys => [keypairpath(user)]) do |session|

            puts "Running #{script}...".att(:bright)
            session.exec!("chmod 700 ~/#{script_config_filename}")
            session.exec!("chmod 700 #{script}")
            puts session.exec!("#{script}")
      
            puts "Removing remote copy of #{script_filename}..."
            session.exec!("rm ~/#{script_config_filename}")
          end
        rescue => ex
          raise "Error executing #{script}: #{ex.message}"
        end
      end
    
      
      tf.delete     # remove local copy of config_file
      #switch_user   # return to the requested user
    end
    
    def write_to_file(filename, content, type)
      type = (type == :append) ? 'a' : 'w'
      f = File.open(filename,type)
      f.puts content
      f.close
    end
    
    
  end
end