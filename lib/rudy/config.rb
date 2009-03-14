

module Rudy
  require 'caesars'
  
  class Config < Caesars::Config
    class Machines < Caesars
    end
    
    
    class AWSInfo < Caesars
      def valid?
        (!account.nil? && !accesskey.nil? && !secretkey.nil?) &&
        (!account.empty? && !accesskey.empty? && !secretkey.empty?) 
      end
    end

    class Defaults < Caesars
    end


    class Routines < Caesars

      def create(*args, &b)
        hash_handler(:create, *args, &b)
      end
      def destroy(*args, &b)
        hash_handler(:destroy, *args, &b)
      end
      def restore(*args, &b)
        hash_handler(:restore, *args, &b)
      end
      def mount(*args, &b)
        hash_handler(:mount, *args, &b)
      end

      #
      # Force the specified keyword to always be treated as a hash. 
      # Example:
      #
      #     startup do
      #       disks do
      #         create "/path/2"         # Available as hash: [action][disks][create][/path/2] == {}
      #         create "/path/4" do      # Available as hash: [action][disks][create][/path/4] == {size => 14}
      #           size 14
      #         end
      #       end
      #     end
      #
      def hash_handler(caesars_meth, *args, &b)
        # TODO: Move to caesars
        return @caesars_properties[caesars_meth] if @caesars_properties.has_key?(caesars_meth) && args.empty? && b.nil?
        return nil if args.empty? && b.nil?
        return method_missing(caesars_meth, *args, &b) if args.empty?

        caesars_name = args.shift

        prev = @caesars_pointer
        @caesars_pointer[caesars_meth] ||= Caesars::Hash.new
        hash = Caesars::Hash.new
        @caesars_pointer = hash
        b.call if b
        @caesars_pointer = prev
        @caesars_pointer[caesars_meth][caesars_name] = hash 
        @caesars_pointer = prev
      end
    end


    dsl Rudy::Config::AWSInfo::DSL
    dsl Rudy::Config::Defaults::DSL
    dsl Rudy::Config::Routines::DSL
    dsl Rudy::Config::Machines::DSL

    
    def postprocess
      # TODO: give caesar attributes setter methods
      self.awsinfo.cert &&= File.expand_path(self.awsinfo.cert)
      self.awsinfo.privatekey &&= File.expand_path(self.awsinfo.privatekey)
    end
    
    def look_and_load
      cwd = Dir.pwd
      # Rudy looks for configs in all these locations
      @paths += Dir.glob(File.join('/etc', 'rudy', '*.rb')) || []
      @paths += Dir.glob(File.join(cwd, 'config', 'rudy', '*.rb')) || []
      @paths += Dir.glob(File.join(cwd, '.rudy', '*.rb')) || []
      refresh
    end
    
    
  end
end


