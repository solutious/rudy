

module Rudy
  require 'caesars'

  class AWSInfo < Caesars
    def valid?
      (!account.nil? && !accesskey.nil? && !secretkey.nil?) &&
      (!account.empty? && !accesskey.empty? && !secretkey.empty?) 
    end
  end

  class Defaults < Caesars
    def valid?
      true
    end
  end
  
  
  class Routines < Caesars
    def valid?
      true
    end
  end
  
  class Machines < Caesars
    def valid?
      true
    end
    
    
    def create(*args, &b)
      list_handler(:create, *args, &b)
    end
    def destroy(*args, &b)
      list_handler(:destroy, *args, &b)
    end
    def restore(*args, &b)
      list_handler(:restore, *args, &b)
    end
    
    #
    #     action do
    #       disks do
    #         create "/path/2" do
    #           prop
    #
    def list_handler(caesars_meth, *args, &b)
      
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
  
  class Config < Caesars::Config
    dsl Rudy::AWSInfo::DSL
    dsl Rudy::Defaults::DSL
    dsl Rudy::Routines::DSL
    dsl Rudy::Machines::DSL
    
    def postprocess
      # TODO: give caesar attributes setter methods
      self.awsinfo.cert = File.expand_path(self.awsinfo.cert) if self.awsinfo.cert
      #self.awsinfo.privatekey = File.expand_path(self.awsinfo.privatekey) if self.awsinfo.privatekey
      self.defaults.region = "POOP"
    end
    
    def look_and_load
      cwd = Dir.pwd
      files = Dir.glob(File.join(cwd, 'config', 'rudy', '*.rb')) || []
      @paths += files unless files.empty?
      @verbose = true
      refresh
    end
    
    
  end
end


