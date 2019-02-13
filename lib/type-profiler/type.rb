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
      def initialize(idx)
        @idx = idx
      end

      attr_reader :idx

      def inspect
        "Type::Class[#{ @idx }]"
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
      def initialize(id, type)
        @id = id
        @type = type
      end

      attr_reader :id, :type

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
          elems = elems.map {|elem| elem.map {|ty| ty.strip_local_info_core(lenv, visited) } }
          Array.new(elems, @type)
        end
      end

      def get_method(mid, genv)
        @type.get_method(mid, genv)
      end
    end

    class Array < Type
      def initialize(elems, type)
        @elems = elems
        @type = type
        # XXX: need infinite recursion
      end

      attr_reader :elems, :type

      def inspect
        #"Type::Array#{ @elems.inspect }"
        @type.inspect
      end

      def screen_name(genv)
        "[" + @elems.map do |elem|
          elem.map do |ty|
            ty.screen_name(genv)
          end.join(" | ")
        end.join(", ") + "]"
      end

      def strip_local_info_core(lenv, visited)
        self
      end

      def get_method(mid, genv)
        raise
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
        Type::Array.new(obj.map {|arg| [guess_literal_type(arg)] }, ty)
      when ::String
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:str]))
      when ::Regexp
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:regexp]))
      when ::NilClass
        Type::Builtin[:nil]
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
