
module Cond
  module CondInner
    class Stack
      def initialize
        @array = Array.new
      end

      def empty?
        @array.empty?
      end
      
      def top
        @array.last
      end
      
      def push(obj)
        @array.push(obj)
        self
      end

      def pop
        @array.pop
      end
    end
  end
end