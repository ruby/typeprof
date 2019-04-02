module TypeProfiler
  class Type
    include Utils::StructuralEquality

    def initialize
      raise "cannot instanciate abstract type"
    end

    Builtin = {}

    def strip_local_info(lenv)
      strip_local_info_core(lenv, {})
    end

    def strip_local_info_core(lenv, visited)
      self
    end

    def consistent?(other)
      return true if other == Type::Any.new
      self == other
    end

    class Any < Type
      def initialize
      end

      def inspect
        "Type::Any"
      end

      def screen_name(genv)
        "any"
      end

      def get_method(mid, genv)
        nil
      end

      def consistent?(other)
        true
      end
    end

    class Class < Type
      def initialize(idx, name)
        @idx = idx
        @_name = name
      end

      attr_reader :idx

      def inspect
        "Type::Class[#{ @idx }]#{ @_name ? "(#@_name)": "" }"
      end

      def screen_name(genv)
        "#{ genv.get_class_name(self) }.class"
      end

      def get_method(mid, genv)
        genv.get_singleton_method(self, mid)
      end
    end

    class Instance < Type
      def initialize(klass)
        @klass = klass
      end

      attr_reader :klass

      def inspect
        "Type::Instance[#{ @klass.inspect }]"
      end

      def screen_name(genv)
        genv.get_class_name(@klass)
      end

      def get_method(mid, genv)
        genv.get_method(@klass, mid)
      end
    end

    # not used?
    class Symbol < Type
      def initialize(sym)
        @sym = sym
      end

      attr_reader :sym

      def inspect
        "Type::Symbol[#{ @sym.inspect }]"
      end

      def screen_name(_genv)
        @sym.inspect
      end
    end

    class ISeq < Type
      def initialize(iseq)
        @iseq = iseq
      end

      attr_reader :iseq

      def inspect
        "Type::ISeq[#{ @iseq }]"
      end

      def screen_name(_genv)
        raise NotImplementedError
      end
    end

    class ISeqProc < Type
      def initialize(iseq, lenv, type)
        @iseq = iseq
        @lenv = lenv
        @type = type
      end

      attr_reader :iseq, :lenv

      def inspect
        "#<ISeqProc>"
      end

      def screen_name(genv)
        "??ISeqProc??"
      end

      def get_method(mid, genv)
        @type.get_method(mid, genv)
      end
    end

    class TypedProc < Type
      def initialize(arg_tys, ret_ty, type)
        # XXX: need to receive blk_ty?
        # XXX: may refactor "arguments = arg_tys * blk_ty" out
        @arg_tys = arg_tys
        @ret_ty = ret_ty
        @type = type
      end

      attr_reader :arg_tys, :ret_ty
    end

    # local info
    class Literal < Type
      def initialize(lit, type)
        @lit = lit
        @type = type
      end

      attr_reader :lit, :type

      def inspect
        "Type::Literal[#{ @lit.inspect }, #{ @type.inspect }]"
      end

      def screen_name(genv)
        @type.screen_name(genv) + "<#{ @lit.inspect }>"
      end

      def strip_local_info_core(lenv, visited)
        @type
      end

      def get_method(mid, genv)
        @type.get_method(mid, genv)
      end
    end

    class LocalArray < Type
      def initialize(id, base_type)
        @id = id
        @base_type = base_type
      end

      attr_reader :id, :base_type

      def inspect
        "Type::LocalArray[#{ @id }]"
      end

      def screen_name(genv)
        raise "LocalArray must not be included in signature"
      end

      def strip_local_info_core(lenv, visited)
        if visited[self]
          Type::Any.new
        else
          visited[self] = true
          elems = lenv.get_array_elem_types(@id)
          elems = elems.strip_local_info_core(lenv, visited)
          Array.new(elems, @base_type)
        end
      end

      def get_method(mid, genv)
        @base_type.get_method(mid, genv)
      end
    end

    class Array < Type
      def initialize(elems, base_type)
        @elems = elems
        @base_type = base_type
        # XXX: need infinite recursion
      end

      attr_reader :elems, :base_type

      def inspect
        #"Type::Array#{ @elems.inspect }"
        @base_type.inspect
      end

      def screen_name(genv)
        @elems.screen_name(genv)
      end

      def strip_local_info_core(lenv, visited)
        self
      end

      def get_method(mid, genv)
        raise
      end

      def self.tuple(elems, base_type = Type::Instance.new(Type::Builtin[:ary]))
        new(Tuple.new(*elems), base_type)
      end

      def self.seq(elems, base_type = Type::Instance.new(Type::Builtin[:ary]))
        new(Seq.new(elems), base_type)
      end

      class Seq
        include Utils::StructuralEquality

        def initialize(elems)
          raise if !elems.is_a?(Union)
          @elems = elems
        end

        attr_reader :elems

        def strip_local_info_core(lenv, visited)
          Seq.new(Union.new(*@elems.types.map {|ty| ty.strip_local_info_core(lenv, visited) }))
        end

        def screen_name(genv)
          "Array[" + @elems.screen_name(genv) + "]"
        end

        def deploy_type(lenv, id)
          elems = Type::Union.new(*@elems.types.map do |ty|
            lenv, ty, id = lenv.deploy_type(ty, id)
            ty
          end)
          return lenv, Seq.new(elems), id
        end

        def types
          @elems.types
        end

        def [](idx)
          @elems
        end

        def update(idx, ty)
          Seq.new(Type::Union.new(*(@elems.types | [ty])))
        end
      end

      class Tuple
        include Utils::StructuralEquality

        def initialize(*elems)
          @elems = elems
        end

        attr_reader :elems

        def strip_local_info_core(lenv, visited)
          elems = @elems.map do |elem|
            Union.new(*elem.types.map {|ty| ty.strip_local_info_core(lenv, visited) })
          end
          Tuple.new(*elems)
        end

        def screen_name(genv)
          "[" + @elems.map do |elem|
            elem.screen_name(genv)
          end.join(", ") + "]"
        end

        def deploy_type(lenv, id)
          elems = @elems.map do |elem|
            Type::Union.new(*elem.types.map do |ty|
              lenv, ty, id = lenv.deploy_type(ty, id)
              ty
            end)
          end
          return lenv, Tuple.new(*elems), id
        end

        def types
          @elems.flat_map {|union| union.types }.uniq # Is this okay?
        end

        def [](idx)
          @elems[idx] || Type::Union.new(Type::Instance.new(Type::Builtin[:nil])) # HACK
        end

        def update(idx, ty)
          if idx
            if idx < @elems.size
              Tuple.new(*Utils.array_update(@elems, idx, Type::Union.new(ty)))
            else
              raise NotImplementedError
            end
          else
            raise NotImplementedError # to Seq?
          end
        end
      end
    end

    class Union
      include Utils::StructuralEquality

      def initialize(*tys)
        @types = tys.uniq
      end

      attr_reader :types

      def screen_name(genv)
        @types.map do |ty|
          ty.screen_name(genv)
        end.join(" | ")
      end
    end

    def self.guess_literal_type(obj)
      case obj
      when ::Symbol
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:sym]))
      when ::Integer
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:int]))
      when ::Class
        raise "unknown class: #{ obj.inspect }" if !obj.equal?(Object)
        Type::Builtin[:obj]
      when ::TrueClass, ::FalseClass
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:bool]))
      when ::Array
        ty = Type::Instance.new(Type::Builtin[:ary])
        Type::Array.tuple(obj.map {|arg| Union.new(guess_literal_type(arg)) }, ty)
      when ::String
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:str]))
      when ::Regexp
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:regexp]))
      when ::NilClass
        Type::Builtin[:nil]
      when ::Range
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:range]))
      else
        raise "unknown object: #{ obj.inspect }"
      end
    end
  end

  class Signature
    include Utils::StructuralEquality

    def initialize(recv_ty, singleton, mid, arg_tys, blk_ty)
      # XXX: need to support optional, rest, post, and keyword arguments?
      @recv_ty = recv_ty
      @singleton = singleton
      @mid = mid
      @arg_tys = arg_tys
      @blk_ty = blk_ty
    end

    attr_reader :recv_ty, :singleton, :mid, :arg_tys, :blk_ty
  end
end
