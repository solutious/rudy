


module Rudy::AWS
  class EC2::Instance < Storable
    field :aki
    field :ari
    field :launch_index => Time
    field :launch_time
    field :keyname
    field :instance_type
    field :ami
    field :dns_name_private
    field :dns_name_public
    field :awsid
    field :state
    field :zone
    field :reason
    field :groups => Array
    
    def groups
      @groups || []
    end
    
        
    def to_s
      lines = []
      field_names.each do |key|
        next unless self.respond_to?(key)
        val = self.send(key)
        lines << sprintf(" %22s: %s", key, (val.is_a?(Array) ? val.join(', ') : val))
      end
      lines.join($/)
    end
    
  end
end