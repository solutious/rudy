

module Rudy::AWS
  class EC2::Volume < Storable
    field :awsid
    field :status
    field :size
    field :snapshot
    field :zone
    field :create_time
    field :attach_time
    field :instid
    field :device
    
    def to_s
      lines = ["Volume: #{self.awsid.bright}"]
      field_names.each do |n|
         lines << sprintf(" %12s: %s", n, self.send(n)) if self.send(n)
       end
      lines.join($/)
    end
    
  end
end