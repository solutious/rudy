require File.join(File.dirname(__FILE__), '..', 'helper')

module Rudy::Test
  class Case_50_Commands < Test::Unit::TestCase
    include Rudy::AWS  
    
    @@logger = StringIO.new
    

  end
end