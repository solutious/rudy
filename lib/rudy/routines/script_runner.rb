
require 'tempfile'

module Rudy::Routines
  class ScriptRunner
    include Rudy::Huxtable
    
    def execute(instance, routine, before_or_after)
      return false unless instance
      
      rscripts = @@config.routines.find_deferred(@@global.environment, @@global.role, routine, before_or_after) || []
      rscripts &&= [rscripts].flatten # Make sure it's an Array
      if !rscripts || rscripts.empty?
        @logger.puts "No scripts defined."
        return
      end
      
      # The config file will contain settings from ~/.rudy/config
      script_config = @@config.routines.find_deferred(@@global.environment, @@global.role, :config) || {}        
      script_config[:global] = @@global.marshal_dump
      script_config[:global].reject! { |n,v| n == :cert || n == :privatekey }
      script_config_filename = "#{routine}_config.yaml"
      
      tf = Tempfile.new(script_config_filename)
      Rudy::Utils.write_to_file(tf.path, script_config.to_hash.to_yaml, 'w')

      rscripts.each do |rscript|
        user, script = rscript.shift
        
        @logger.puts "User: #{user} (#{user_keypairpath(user)})"
        begin
          Net::SCP.start(instance.dns_name_public, user, :keys => [user_keypairpath(user)]) do |scp|
            scp.upload!(tf.path, "~/#{script_config_filename}") do |ch, name, sent, total|
              "#{name}: #{sent}/#{total}"
            end
          end
        rescue => ex
          raise "Error transfering #{script_config_filename}: #{ex.message} "
        end
        
        begin
          Net::SSH.start(instance.dns_name_public, user, :keys => [user_keypairpath(user)]) do |session|

            puts "Running #{script}...".bright
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
    

    
  end
end