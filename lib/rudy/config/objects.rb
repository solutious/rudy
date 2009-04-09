

class Rudy::Config
  class Machines < Caesars
  end
  
  
  class Accounts < Caesars
    def valid?
      (!aws.nil? && !aws.accesskey.nil? && !aws.secretkey.nil?) &&
      (!aws.account.empty? && !aws.accesskey.empty? && !aws.secretkey.empty?) 
    end
  end

  class Defaults < Caesars
  end

  class Networks < Caesars
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
end