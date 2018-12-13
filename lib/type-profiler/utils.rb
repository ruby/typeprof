module TypeProfiler
  module Utils
    module_function

    def array_update(ary, idx, elem)
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

      def eql?(other)
        ivs1 = instance_variables.sort.reject {|v| v == :@_hash }
        ivs2 = other.instance_variables.sort.reject {|v| v == :@_hash }
        self.class == other.class &&
          ivs1 == ivs2 &&
          ivs1.all? do |v|
            instance_variable_get(v).eql?(other.instance_variable_get(v))
          end
      end

      alias == eql?
    end
  end
end
