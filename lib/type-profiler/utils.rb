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
          (TABLE[self] ||= {})[args] ||= super
        end
      end
    end

    class Set
      include StructuralEquality

      attr_reader :tbl

      def self.[](*values)
        tbl = {}
        h = 0
        values.each do |v|
          tbl[v] = true
          h ^= v.hash
        end
        new(tbl, h)
      end

      TABLE = {}
      def self.new(tbl, hash)
        TABLE[tbl] ||= super(tbl, hash)
      end

      def initialize(tbl, hash)
        @tbl = tbl
        @tbl.freeze
        @hash = hash
      end

      attr_reader :hash

      def each(&blk)
        @tbl.each_key(&blk)
      end

      include Enumerable

      def +(other)
        Set.new(@tbl.merge(other.tbl), hash ^ other.hash)
      end

      def size
        @tbl.size
      end

      def map(&blk)
        tbl = {}
        h = 0
        each do |elem|
          v = yield(elem)
          tbl[v] = true
          h ^= v.hash
        end
        Set.new(tbl, h)
      end

      def inspect
        s = []
        each {|v| s << v.inspect }
        "{#{ s.join(", ") }}"
      end

      def include?(elem)
        @tbl[elem]
      end

      def intersection(other)
        tbl = {}
        h = 0
        each do |elem|
          if other.include?(elem)
            tbl << elem
            h ^= elem.hash
          end
        end
        Set.new(tbl, h)
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

      def [](v)
        @hash[v]
      end

      def delete(v)
        @hash.delete(v)
      end

      def inspect
        s = []
        each {|v| s << v.inspect }
        "{#{ s.join(", ") }}"
      end

      def size
        @hash.size
      end

      def to_set
        Set[*@hash.keys]
      end
    end

    class WorkList
      def initialize
        @heap = []
        @set = MutableSet.new
      end

      def insert(key, val)
        i = @heap.size
        @heap << [key, val]
        while i > 0 && (cmp = @heap[i][0] <=> @heap[i / 2][0]; p @heap[i][0], @heap[i/2][0] if !cmp; cmp) < 0
          @heap[i], @heap[i / 2] = @heap[i / 2], @heap[i]
          i /= 2
        end
        @set << val
      end

      def member?(val)
        @set[val]
      end

      def deletemin
        return nil if @heap.empty?
        val = @heap[0][1]
        @set.delete(val)
        if @heap.size == 1
          @heap.pop
          return val
        end
        @heap[0] = @heap.pop
        i = 0
        while (j = i * 2 + 1) < @heap.size
          j += 1 if j + 1 < @heap.size && (@heap[j][0] <=> @heap[j + 1][0]) >= 0
          break if (@heap[i][0] <=> @heap[j][0]) < 0
          @heap[i], @heap[j] = @heap[j], @heap[i]
          i = j
        end
        return val
      end

      def size
        @heap.size
      end

      def empty?
        @heap.empty?
      end

      def inspect
        "#<#{ self.class }:#{ @heap.map {|_key, val| val }.inspect }>"
      end
    end
  end
end
