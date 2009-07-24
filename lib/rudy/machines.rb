

module Rudy
  
  module Machines
    extend self
    extend Rudy::Metadata::ClassMethods 
    extend Rudy::Huxtable
    
    def get(position)
      tmp = Rudy::Machine.new position
      record = Rudy::Metadata.get tmp.name
      return nil unless record.is_a?(Hash)
      tmp.from_hash record
    end
    
    def find_next_position
      raise "reimplement by looking at position values"
      list = Rudy::Machines.list({}, [:position]) || []
      pos = list.size + 1
      pos.to_s.rjust(2, '0')
    end
    
    # Returns true if any machine metadata exists for this group
    def exists?
      !list.nil?
    end
    
    # Returns true if all machines in the group are running instances
    def running?
      group = list
      return false if group.nil?
      group.collect! { |m| m.instance_running? }
      !group.member?(false)
    end
    
    def create(size=1)
      size ||= current_machine_count.to_i
      group = Array.new(size) do |i|
        m = Rudy::Machine.new(i + 1)
        m.create
        m
      end
    end
    
    def restart
      group = list 
      raise MachineGroupNotRunning, current_group_name if group.nil?
      group.each do |inst|
        inst.restart
      end
      group
    end
    
    def from_hash(h)
      Rudy::Machine.from_hash h
    end
    
  end
  
end