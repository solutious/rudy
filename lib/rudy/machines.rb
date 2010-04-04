

module Rudy
  
  module Machines
    RTYPE = 'm'.freeze
    
    extend self
    extend Rudy::Metadata::ClassMethods 
    extend Rudy::Huxtable
    
    def get(position)
      tmp = Rudy::Machine.new position
      record = Rudy::Metadata.get tmp.name
      return nil unless record.is_a?(Hash)
      tmp.from_hash record
    end
    
    def self.list(*args, &blk)
      machs = super(*args, &blk) || []
      manual = [fetch_machine_param(:hostname)].flatten.compact
      manual.reject! { |m| m.is_a?(Symbol) }
      machs.push *manual
      machs
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
    def create(size=nil)
      if Rudy::Huxtable.global.position.nil?
        size ||= current_machine_count.to_i || 1
        group = Array.new(size) do |i|
          m = Rudy::Machine.new(i + 1)
          m.create
          li "Created: #{m.to_s}"
          m
        end
      else
        m = Rudy::Machine.new(Rudy::Huxtable.global.position)
        m.create
        li "Created: #{m.to_s}"
        group = [m]
      end
      group
    end
    
    def restart
      group = list 
      raise MachineGroupNotRunning, current_machine_group if group.nil?
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