module TypeProfiler
  module Utils
    def self.array_update(ary, idx, elem)
      idx %= ary.size
      ary[0...idx] + [elem] + ary[idx+1..-1]
    end

    module StructuralEquality
      def hash
        @_hash ||=
          begin
            h = 0
            instance_variables.each do |v|
              h ^= instance_variable_get(v).hash if v != :@_hash
            end
            h
          end
      end

      TABLE = {}

      def self.included(klass)
        def klass.new(*args)
          TABLE[[self] + args] ||= super
        end
      end
    end

    class Set
      include StructuralEquality

      def self.[](*values)
        hash = {}
        values.each {|v| hash[v] = true }
        new(hash)
      end

      def initialize(hash)
        @hash = hash
        @hash.freeze
      end

      def each(&blk)
        @hash.each_key(&blk)
      end

      include Enumerable

      def +(other)
        hash = @hash.dup
        other.each {|elem| hash[elem] = true }
        Set.new(hash)
      end

      def size
        @hash.size
      end

      def map(&blk)
        nhash = {}
        each {|elem| nhash[yield(elem)] = true }
        Set.new(nhash)
      end

      def inspect
        s = []
        each {|v| s << v.inspect }
        "{#{ s.join(", ") }}"
      end
    end

    class MutableSet
      def initialize(*values)
        @hash = {}
        values.each {|v| @hash[v] = v }
      end

      def each(&blk)
        @hash.each_key(&blk)
      end

      include Enumerable

      def <<(v)
        @hash[v] = true
      end

      def inspect
        s = []
        each {|v| s << v.inspect }
        "{#{ s.join(", ") }}"
      end

      def size
        @hash.size
      end
    end
  end
end
