

module Rudy
  
  module Machines
    RTYPE = 'm'.freeze
    
    extend self
    extend Rudy::Metadata::ClassMethods 
    include Rudy::Huxtable
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
    def exists?(pos=nil)
      machines = pos.nil? ? list : get(pos)
      !machines.nil?
    end
    
    # Returns true if all machines in the group are running instances
    def running?(pos=nil)
      group = pos.nil? ? list : [get(pos)].compact
      return false if group.nil? || group.empty?
      group.collect! { |m| m.instance_running? }
      !group.member?(false)
    end
    
    # Returns an Array of newly created Rudy::Machine objects
    def create(size=1)
      if @@global.position.nil?
        size ||= current_machine_count.to_i
        group = Array.new(size) do |i|
          m = Rudy::Machine.new(i + 1)
          m.create
          m
        end
      else
        m = Rudy::Machine.new(@@global.position)
        m.create
        [m]
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
      p h
      Rudy::Machine.from_hash h
    end
    
  end
  
end