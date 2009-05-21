#!/usr/bin/ruby

# Tryout - Fix namespace conflicts between Drydock, Rudy, and Caesars
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'drydock'
require 'tryouts'
include Tryouts

Drydock.run = false

tryout("include within module") do
  module SomeModule
    include Drydock
    before do
    end
    puts "Works!"  # Doesn't run
  end
end

tryout("extend within module") do
  module SomeModule
    extend Drydock
    before do
    end
    puts "Works!"  # Runs
  end
end

tryout("use before in main without include or extend") do
  before do
  end
  puts "Works!"   # Runs
end

tryout("include within main, use before in SomeModule") do
  include Drydock
  before do
  end
  module SomeModule
    before do
    end
    puts "just ran SomeModule.before"  # Run
  end
  puts "Works!"  # Runs
end
