
require 'date'

module Rudy
  module SCM
    class GIT
      attr_accessor :base_uri
      
      def initialize(args={:base => ''})
        @base_uri = args[:base]
      end
    end
  end
end