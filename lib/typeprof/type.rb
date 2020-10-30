module TypeProf
  class Type # or AbstractValue
    include Utils::StructuralEquality

    def initialize
      raise "cannot instantiate abstract type"
    end

    Builtin = {}

    def globalize(_env, _visited, _depth)
      self
    end

    def localize(env, _alloc_site, _depth)
      return env, self
    end

    def limit_size(limit)
      self
    end

    def consistent?(other, subst)
      case other
      when Type::Any then true
      when Type::Var then other.add_subst!(self, subst)
      when Type::Union
        other.types.each do |ty2|
          return true if consistent?(ty2, subst)
        end
      else
        self == other
      end
    end

    def each_child
      yield self
    end

    def each_child_global
      yield self
    end

    def union(other)
      return self if self == other # fastpath

      ty1, ty2 = self, other

      ty1 = container_to_union(ty1)
      ty2 = container_to_union(ty2)

      if ty1.is_a?(Union) && ty2.is_a?(Union)
        ty = ty1.types.sum(ty2.types)
        all_elems = ty1.elems.dup || {}
        ty2.elems&.each do |key, elems|
          all_elems[key] = union_elems(all_elems[key], elems)
        end
        all_elems = nil if all_elems.empty?

        Type::Union.new(ty, all_elems).normalize
      else
        ty1, ty2 = ty2, ty1 if ty2.is_a?(Union)
        if ty1.is_a?(Union)
          Type::Union.new(ty1.types.add(ty2), ty1.elems).normalize
        else
          Type::Union.new(Utils::Set[ty1, ty2], nil).normalize
        end
      end
    end

    private def container_to_union(ty)
      case ty
      when Type::Array, Type::Hash
        Type::Union.new(Utils::Set[], { [ty.class, ty.base_type] => ty.elems })
      else
        ty
      end
    end

    private def union_elems(e1, e2)
      if e1
        if e2
          e1.union(e2)
        else
          e1
        end
      else
        e2
      end
    end

    def substitute(_subst, _depth)
      raise "cannot substitute abstract type: #{ self.class }"
    end

    DummySubstitution = Object.new
    def DummySubstitution.[](_)
      Type.any
    end

    def remove_type_vars
      substitute(DummySubstitution, Config.options[:type_depth_limit])
    end

    class Any < Type
      def initialize
      end

      def inspect
        "Type::Any"
      end

      def screen_name(scratch)
        "untyped"
      end

      def get_method(mid, scratch)
        nil
      end

      def consistent?(other, subst)
        # need to create a type assignment if other is Var
        other.add_subst!(self, subst) if other.is_a?(Type::Var)
        true
      end

      def substitute(_subst, _depth)
        self
      end
    end

    class Void < Any
      def inspect
        "Type::Void"
      end

      def screen_name(scratch)
        "void"
      end
    end


    class Union < Type
      def initialize(tys, elems)
        raise unless tys.is_a?(Utils::Set)
        @types = tys # Set

        # invariant check
        local = nil
        tys.each do |ty|
          raise ty.inspect unless ty.is_a?(Type)
          local = true if ty.is_a?(LocalArray) || ty.is_a?(LocalHash)
        end
        raise if local && elems

        @elems = elems
      end

      def limit_size(limit)
        return Type.any if limit <= 0
        tys = Utils::Set[]
        @types.each do |ty|
          tys = tys.add(ty.limit_size(limit - 1))
        end
        elems = @elems&.to_h do |key, elems|
          [key, elems.limit_size(limit - 1)]
        end
        Union.new(tys, elems)
      end

      attr_reader :types, :elems

      def normalize
        if @types.size == 1 && !@elems
          @types.each {|ty| return ty }
        elsif @types.size == 0
          if @elems && @elems.size == 1
            (container_kind, base_type), elems = @elems.first
            # container_kind = Type::Array or Type::Hash
            container_kind.new(elems, base_type)
          else
            self
          end
        else
          self
        end
      end

      def each_child(&blk) # local
        @types.each(&blk)
        raise if @elems
      end

      def each_child_global(&blk)
        @types.each(&blk)
        @elems&.each do |(container_kind, base_type), elems|
          yield container_kind.new(elems, base_type)
        end
      end

      def inspect
        a = []
        a << "Type::Union{#{ @types.to_a.map {|ty| ty.inspect }.join(", ") }"
        @elems&.each do |(container_kind, base_type), elems|
          a << ", #{ container_kind.new(elems, base_type).inspect }"
        end
        a << "}"
        a.join
      end

      def screen_name(scratch)
        types = @types.to_a
        @elems&.each do |(container_kind, base_type), elems|
          types << container_kind.new(elems, base_type)
        end
        if types.size == 0
          "bot"
        else
          types = types.to_a
          optional = !!types.delete(Type::Instance.new(Type::Builtin[:nil]))
          bool = false
          if types.include?(Type::Instance.new(Type::Builtin[:false])) &&
             types.include?(Type::Instance.new(Type::Builtin[:true]))
            types.delete(Type::Instance.new(Type::Builtin[:false]))
            types.delete(Type::Instance.new(Type::Builtin[:true]))
            bool = true
          end
          types.delete(Type.any) unless Config.options[:pedantic_output]
          iseq_proc_tys, types = types.partition {|ty| ty.is_a?(ISeqProc) }
          types = types.map {|ty| ty.screen_name(scratch) }
          types << scratch.show_proc_signature(iseq_proc_tys) unless iseq_proc_tys.empty?
          types << "bool" if bool
          types = types.sort
          if optional
            if types.size == 1
              types.first + "?"
            else
              "(#{ types.join (" | ") })?"
            end
          else
            types.join (" | ")
          end
        end
      rescue SystemStackError
        p self
        raise
      end

      def globalize(env, visited, depth)
        return Type.any if depth <= 0
        tys = Utils::Set[]
        raise if @elems

        elems = {}
        @types.each do |ty|
          ty = ty.globalize(env, visited, depth - 1)
          case ty
          when Type::Array, Type::Hash
            key = [ty.class, ty.base_type]
            elems[key] = union_elems(elems[key], ty.elems)
          else
            tys = tys.add(ty)
          end
        end
        elems = nil if elems.empty?

        Type::Union.new(tys, elems).normalize
      end

      def localize(env, alloc_site, depth)
        return env, Type.any if depth <= 0
        tys = @types.map do |ty|
          alloc_site2 = alloc_site.add_id(ty)
          env, ty2 = ty.localize(env, alloc_site2, depth - 1)
          ty2
        end
        @elems&.each do |(container_kind, base_type), elems|
          ty = container_kind.new(elems, base_type)
          alloc_site2 = alloc_site.add_id(container_kind.name.to_sym).add_id(base_type)
          env, ty = ty.localize(env, alloc_site2, depth - 1)
          tys = tys.add(ty)
        end
        ty = Union.new(tys, nil).normalize
        return env, ty
      end

      def consistent?(other, subst)
        case other
        when Type::Any then true
        when Type::Var then other.add_subst!(self, subst)
        when Type::Union
          # this is very conservative to create subst:
          # consistent?( int | str, int | X) creates { X => int | str } but should be { X => str }???
          @types.each do |ty1|
            other.types.each do |ty2|
              subst2 = subst.dup
              if ty1.consistent?(ty2, subst2)
                subst.replace(subst2)
                # XXX: need to check other pairs to create conservative substitution??
                # consistent?( X | :foo, str | int ) may return { X => str } or { X => int } but should be { X => str | int }?
                return true
              end
            end
          end
          return true if @types.size == 0 && other.types.size == 0 # XXX: is this okay?
          # TODO: array argument?
          return false
        else
          @types.each do |ty1|
            return true if ty1.consistent?(other, subst)
          end
          # TODO: array argument?
          return false
        end
      end

      def substitute(subst, depth)
        return Type.any if depth <= 0
        unions = []
        tys = Utils::Set[]
        @types.each do |ty|
          ty = ty.substitute(subst, depth - 1)
          case ty
          when Union
            unions << ty
          else
            tys = tys.add(ty)
          end
        end
        elems = @elems&.to_h do |(container_kind, base_type), elems|
          [[container_kind, base_type], elems.substitute(subst, depth - 1)]
        end
        ty = Union.new(tys, elems)
        unions.each do |ty0|
          ty = ty.union(ty0)
        end
        ty
      end
    end

    def self.any
      @any ||= Any.new
    end

    def self.bot
      @bot ||= Union.new(Utils::Set[], nil)
    end

    def self.bool
      @bool ||= Union.new(Utils::Set[
        Instance.new(Type::Builtin[:true]),
        Instance.new(Type::Builtin[:false])
      ], nil)
    end

    def self.nil
      @nil ||= Instance.new(Type::Builtin[:nil])
    end

    def self.optional(ty)
      ty.union(Type.nil)
    end

    class Var < Type
      def initialize(name)
        @name = name
      end

      def screen_name(scratch)
        "Var[#{ @name }]"
      end

      def substitute(subst, depth)
        if subst[self]
          subst[self].limit_size(depth)
        else
          self
        end
      end

      def consistent?(other, subst)
        raise "should not be called: #{ self }"
      end

      def add_subst!(ty, subst)
        if subst[self]
          subst[self] = subst[self].union(ty)
        else
          subst[self] = ty
        end
        true
      end
    end

    class Class < Type # or Module
      def initialize(kind, idx, type_params, superclass, name)
        @kind = kind # :class | :module
        @idx = idx
        @type_params = type_params
        @superclass = superclass
        @_name = name
      end

      attr_reader :kind, :idx, :type_params, :superclass

      def inspect
        if @_name
          "#{ @_name }@#{ @idx }"
        else
          "Class[#{ @idx }]"
        end
      end

      def screen_name(scratch)
        "#{ scratch.get_class_name(self) }.class"
      end

      def get_method(mid, scratch)
        scratch.get_method(self, true, mid)
      end

      def consistent?(other, subst)
        case other
        when Type::Any then true
        when Type::Var then other.add_subst!(self, subst)
        when Type::Union
          other.types.each do |ty|
            return true if consistent?(ty, subst)
          end
          return false
        when Type::Class
          ty = self
          loop do
            # ad-hoc
            return false if !ty || !other # module

            return true if ty.idx == other.idx
            return false if ty.idx == 0 # Object
            ty = ty.superclass
          end
        when Type::Instance
          return true if other.klass == Type::Builtin[:obj] || other.klass == Type::Builtin[:class] || other.klass == Type::Builtin[:module]
          return false
        else
          false
        end
      end

      def substitute(_subst, _depth)
        self
      end
    end

    class Instance < Type
      def initialize(klass)
        raise unless klass
        raise if klass == Type.any
        @klass = klass
      end

      attr_reader :klass

      def inspect
        "I[#{ @klass.inspect }]"
      end

      def screen_name(scratch)
        case @klass
        when Type::Builtin[:nil] then "nil"
        when Type::Builtin[:true] then "true"
        when Type::Builtin[:false] then "false"
        else
          scratch.get_class_name(@klass)
        end
      end

      def get_method(mid, scratch)
        scratch.get_method(@klass, false, mid)
      end

      def consistent?(other, subst)
        case other
        when Type::Any then true
        when Type::Var then other.add_subst!(self, subst)
        when Type::Union
          other.types.each do |ty|
            return true if consistent?(ty, subst)
          end
          return false
        when Type::Instance
          @klass.consistent?(other.klass, subst)
        when Type::Class
          return true if @klass == Type::Builtin[:obj] || @klass == Type::Builtin[:class] || @klass == Type::Builtin[:module]
          return false
        else
          false
        end
      end

      def substitute(subst, depth)
        Instance.new(@klass.substitute(subst, depth))
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

      def screen_name(_scratch)
        raise NotImplementedError
      end
    end

    class ISeqProc < Type
      def initialize(iseq, ep, type)
        @iseq = iseq
        @ep = ep
        @type = type
      end

      attr_reader :iseq, :ep, :type

      def inspect
        "#<ISeqProc>"
      end

      def consistent?(other, subst)
        case other
        when Type::Any then true
        when Type::Var then other.add_subst!(self, subst)
        when Type::Union
          other.types.each do |ty2|
            return true if consistent?(ty2, subst)
          end
        when Type::ISeqProc
          raise "assert false"
        when Type::TypedProc
          true # XXX: handle type vars in TypedProc!
        else
          self == other
        end
      end

      def screen_name(scratch)
        scratch.proc_screen_name(self)
      end

      def get_method(mid, scratch)
        @type.get_method(mid, scratch)
      end

      def substitute(_subst, _depth)
        self # XXX
      end
    end

    class TypedProc < Type
      def initialize(msig, ret_ty, type)
        @msig = msig
        @ret_ty = ret_ty
        @type = type
      end

      attr_reader :msig, :ret_ty

      def consistent?(other, subst)
        case other
        when Type::Any then true
        when Type::Var then other.add_subst!(self, subst)
        when Type::Union
          other.types.each do |ty2|
            return true if consistent?(ty2, subst)
          end
        when Type::ISeqProc
          raise "assert false"
        when Type::TypedProc
          self == other # XXX: handle type vars in TypedProc!
        else
          self == other
        end
      end

      def screen_name(scratch)
        "TypedProc[...]" # TODO: use RBS syntax
      end

      def get_method(mid, scratch)
        @type.get_method(mid, scratch)
      end

      def substitute(subst, depth)
        msig = @msig.substitute(subst, depth)
        ret_ty = @ret_ty.substitute(subst, depth)
        type = @type.substitute(subst, depth)
        TypedProc.new(msig, ret_ty, type)
      end
    end

    class Symbol < Type
      def initialize(sym, type)
        @sym = sym
        @type = type
      end

      attr_reader :sym, :type

      def inspect
        "Type::Symbol[#{ @sym ? @sym.inspect : "(dynamic symbol)" }, #{ @type.inspect }]"
      end

      def consistent?(other, subst)
        case other
        when Var
          other.add_subst!(self, subst)
        when Symbol
          @sym == other.sym
        else
          @type.consistent?(other, subst)
        end
      end

      def screen_name(scratch)
        if @sym
          @sym.inspect
        else
          @type.screen_name(scratch)
        end
      end

      def get_method(mid, scratch)
        @type.get_method(mid, scratch)
      end

      def substitute(_subst, _depth)
        self # dummy
      end
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

      def screen_name(scratch)
        @type.screen_name(scratch) + "<#{ @lit.inspect }>"
      end

      def globalize(_env, _visited, _depth)
        @type
      end

      def get_method(mid, scratch)
        @type.get_method(mid, scratch)
      end

      def consistent?(other, subst)
        @type.consistent?(other, subst)
      end
    end

    class HashGenerator
      def initialize
        @map_tys = {}
      end

      attr_reader :map_tys

      def []=(k_ty, v_ty)
        k_ty.each_child_global do |k_ty|
          # This is a temporal hack to mitigate type explosion
          k_ty = Type.any if k_ty.is_a?(Type::Array)
          k_ty = Type.any if k_ty.is_a?(Type::Hash)

          if @map_tys[k_ty]
            @map_tys[k_ty] = @map_tys[k_ty].union(v_ty)
          else
            @map_tys[k_ty] = v_ty
          end
        end
      end
    end

    def self.gen_hash(base_ty = Type::Instance.new(Type::Builtin[:hash]))
      hg = HashGenerator.new
      yield hg
      Type::Hash.new(Type::Hash::Elements.new(hg.map_tys), base_ty)
    end

    def self.guess_literal_type(obj)
      case obj
      when ::Symbol
        Type::Symbol.new(obj, Type::Instance.new(Type::Builtin[:sym]))
      when ::Integer
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:int]))
      when ::Rational
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:rational]))
      when ::Float
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:float]))
      when ::Class
        return Type.any if obj < Exception
        case obj
        when ::Object
          Type::Builtin[:obj]
        when ::Array
          Type::Builtin[:ary]
        else
          raise "unknown class: #{ obj.inspect }"
        end
      when ::TrueClass
        Type::Instance.new(Type::Builtin[:true])
      when ::FalseClass
        Type::Instance.new(Type::Builtin[:false])
      when ::Array
        base_ty = Type::Instance.new(Type::Builtin[:ary])
        lead_tys = obj.map {|arg| guess_literal_type(arg) }
        Type::Array.new(Type::Array::Elements.new(lead_tys), base_ty)
      when ::Hash
        Type.gen_hash do |h|
          obj.each do |k, v|
            k_ty = guess_literal_type(k).globalize(nil, {}, Config.options[:type_depth_limit])
            v_ty = guess_literal_type(v)
            h[k_ty] = v_ty
          end
        end
      when ::String
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:str]))
      when ::Regexp
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:regexp]))
      when ::NilClass
        Type.nil
      when ::Range
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:range]))
      else
        raise "unknown object: #{ obj.inspect }"
      end
    end

    def self.builtin_global_variable_type(var)
      case var
      when :$_, :$/, :$\, :$,, :$;
        Type.optional(Type::Instance.new(Type::Builtin[:str]))
      when :$0, :$PROGRAM_NAME
        Type::Instance.new(Type::Builtin[:str])
      when :$~
        Type.optional(Type::Instance.new(Type::Builtin[:matchdata]))
      when :$., :$$
        Type::Instance.new(Type::Builtin[:int])
      when :$?
        Type.optional(Type::Instance.new(Type::Builtin[:int]))
      when :$!
        Type.optional(Type::Instance.new(Type::Builtin[:exc]))
      when :$@
        str = Type::Instance.new(Type::Builtin[:str])
        base_ty = Type::Instance.new(Type::Builtin[:ary])
        Type.optional(Type::Array.new(Type::Array::Elements.new([], str), base_ty))
      when :$*, :$:, :$LOAD_PATH, :$", :$LOADED_FEATURES
        str = Type::Instance.new(Type::Builtin[:str])
        base_ty = Type::Instance.new(Type::Builtin[:ary])
        Type::Array.new(Type::Array::Elements.new([], str), base_ty)
      when :$<
        :ARGF
      when :$>
        :STDOUT
      when :$DEBUG
        Type.bool
      when :$FILENAME
        Type::Instance.new(Type::Builtin[:str])
      when :$stdin
        :STDIN
      when :$stdout
        :STDOUT
      when :$stderr
        :STDERR
      when :$VERBOSE
        Type.bool.union(Type.nil)
      else
        nil
      end
    end
  end

  class Signature
    include Utils::StructuralEquality

    def screen_name(scratch)
      str = @lead_tys.map {|ty| ty.screen_name(scratch) }
      if @opt_tys
        str += @opt_tys.map {|ty| "?" + ty.screen_name(scratch) }
      end
      if @rest_ty
        str << ("*" + @rest_ty.screen_name(scratch))
      end
      if @post_tys
        str += @post_tys.map {|ty| ty.screen_name(scratch) }
      end
      if @kw_tys
        @kw_tys.each do |req, sym, ty|
          opt = req ? "" : "?"
          str << "#{ opt }#{ sym }: #{ ty.screen_name(scratch) }"
        end
      end
      if @kw_rest_ty
        str << ("**" + @kw_rest_ty.screen_name(scratch))
      end
      str = str.empty? ? "" : "(#{ str.join(", ") })"

      optional = false
      blks = []
      @blk_ty.each_child_global do |ty|
        if ty.is_a?(Type::ISeqProc)
          blks << ty
        else
          # XXX: how should we handle types other than Type.nil
          optional = true
        end
      end
      if blks != []
        str << " " if str != ""
        str << "?" if optional
        str << scratch.show_block_signature(blks)
      end

      str
    end
  end

  class MethodSignature < Signature
    def initialize(lead_tys, opt_tys, rest_ty, post_tys, kw_tys, kw_rest_ty, blk_ty)
      @lead_tys = lead_tys
      @opt_tys = opt_tys
      @rest_ty = rest_ty
      @post_tys = post_tys
      @kw_tys = kw_tys
      kw_tys.each {|a| raise if a.size != 3 } if kw_tys
      @kw_rest_ty = kw_rest_ty
      @blk_ty = blk_ty
    end

    attr_reader :lead_tys, :opt_tys, :rest_ty, :post_tys, :kw_tys, :kw_rest_ty, :blk_ty

    def substitute(subst, depth)
      lead_tys = @lead_tys.map {|ty| ty.substitute(subst, depth - 1) }
      opt_tys = @opt_tys.map {|ty| ty.substitute(subst, depth - 1) }
      rest_ty = @rest_ty&.substitute(subst, depth - 1)
      post_tys = @post_tys.map {|ty| ty.substitute(subst, depth - 1) }
      kw_tys = @kw_tys.map {|req, key, ty| [req, key, ty.substitute(subst, depth - 1)] }
      kw_rest_ty = @kw_rest_ty&.substitute(subst, depth - 1)
      blk_ty = @blk_ty.substitute(subst, depth - 1)
      MethodSignature.new(lead_tys, opt_tys, rest_ty, post_tys, kw_tys, kw_rest_ty, blk_ty)
    end

    def merge(other)
      raise if @lead_tys.size != other.lead_tys.size
      raise if @post_tys.size != other.post_tys.size
      if @kw_tys && other.kw_tys
        kws1 = {}
        @kw_tys.each {|req, kw, _| kws1[kw] = req }
        kws2 = {}
        other.kw_tys.each {|req, kw, _| kws2[kw] = req }
        (kws1.keys & kws2.keys).each do |kw|
          raise if !!kws1[kw] != !!kws2[kw]
        end
      elsif @kw_tys || other.kw_tys
        (@kw_tys || other.kw_tys).each do |req,|
          raise if req
        end
      end
      lead_tys = @lead_tys.zip(other.lead_tys).map {|ty1, ty2| ty1.union(ty2) }
      if @opt_tys || other.opt_tys
        opt_tys = []
        [@opt_tys.size, other.opt_tys.size].max.times do |i|
          ty1 = @opt_tys[i]
          ty2 = other.opt_tys[i]
          ty = ty1 ? ty2 ? ty1.union(ty2) : ty1 : ty2
          opt_tys << ty
        end
      end
      if @rest_ty || other.rest_ty
        if @rest_ty && other.rest_ty
          rest_ty = @rest_ty.union(other.rest_ty)
        else
          rest_ty = @rest_ty || other.rest_ty
        end
      end
      post_tys = @post_tys.zip(other.post_tys).map {|ty1, ty2| ty1.union(ty2) }
      if @kw_tys && other.kw_tys
        kws1 = {}
        @kw_tys.each {|req, kw, ty| kws1[kw] = [req, ty] }
        kws2 = {}
        other.kw_tys.each {|req, kw, ty| kws2[kw] = [req, ty] }
        kw_tys = (kws1.keys | kws2.keys).map do |kw|
          req1, ty1 = kws1[kw]
          _req2, ty2 = kws2[kw]
          ty1 ||= Type.bot
          ty2 ||= Type.bot
          [!!req1, kw, ty1.union(ty2)]
        end
      elsif @kw_tys || other.kw_tys
        kw_tys = @kw_tys || other.kw_tys
      else
        kw_tys = nil
      end
      if @kw_rest_ty || other.kw_rest_ty
        if @kw_rest_ty && other.kw_rest_ty
          kw_rest_ty = @kw_rest_ty.union(other.kw_rest_ty)
        else
          kw_rest_ty = @kw_rest_ty || other.kw_rest_ty
        end
      end
      blk_ty = @blk_ty.union(other.blk_ty) if @blk_ty
      MethodSignature.new(lead_tys, opt_tys, rest_ty, post_tys, kw_tys, kw_rest_ty, blk_ty)
    end
  end

  class BlockSignature < Signature
    def initialize(lead_tys, opt_tys, rest_ty, blk_ty)
      @lead_tys = lead_tys
      @opt_tys = opt_tys
      @rest_ty = rest_ty
      @blk_ty = blk_ty
      # TODO: kw_tys
    end

    attr_reader :lead_tys, :opt_tys, :rest_ty, :blk_ty

    def merge(bsig)
      if @rest_ty && bsig.rest_ty
        rest_ty = @rest_ty.union(bsig.rest_ty)
        BlockSignature.new(@lead_tys, [], rest_ty, @blk_ty.union(bsig.blk_ty))
      elsif @rest_ty || bsig.rest_ty
        rest_ty = @rest_ty || bsig.rest_ty
        rest_ty = @opt_tys.inject(rest_ty, &:union)
        rest_ty = bsig.opt_tys.inject(rest_ty, &:union)

        lead_tys = []
        [@lead_tys.size, bsig.lead_tys.size].max.times do |i|
          ty1 = @lead_tys[i]
          ty2 = bsig.lead_tys[i]
          if ty1 && ty2
            lead_tys << ty1.union(ty2)
          else
            rest_ty = rest_ty.union(ty1 || ty2)
          end
        end

        BlockSignature.new(lead_tys, [], rest_ty, @blk_ty.union(bsig.blk_ty))
      else
        lead_tys = []
        n = [@lead_tys.size, bsig.lead_tys.size].min
        n.times do |i|
          lead_tys << @lead_tys[i].union(bsig.lead_tys[i])
        end
        opt_tys1 = @lead_tys[n..] + @opt_tys
        opt_tys2 = bsig.lead_tys[n..] + bsig.opt_tys
        opt_tys = []
        [opt_tys1.size, opt_tys2.size].max.times do |i|
          if opt_tys1[i] && opt_tys2[i]
            opt_tys << opt_tys1[i].union(opt_tys2[i])
          else
            opt_tys << (opt_tys1[i] || opt_tys2[i])
          end
        end
        BlockSignature.new(lead_tys, opt_tys, nil, @blk_ty.union(bsig.blk_ty))
      end
    end
  end

  # Arguments for callee side
  class FormalArguments
    def initialize(lead_tys, opt_tys, rest_ty, post_tys, kw_tys, kw_rest_ty, blk_ty)
      @lead_tys = lead_tys
      @opt_tys = opt_tys
      @rest_ty = rest_ty
      @post_tys = post_tys
      @kw_tys = kw_tys
      kw_tys.each {|a| raise if a.size != 3 } if kw_tys
      @kw_rest_ty = kw_rest_ty
      @blk_ty = blk_ty
    end

    attr_reader :lead_tys, :opt_tys, :rest_ty, :post_tys, :kw_tys, :kw_rest_ty, :blk_ty
  end

  # Arguments from caller side
  class ActualArguments
    def initialize(lead_tys, rest_ty, kw_tys, blk_ty)
      @lead_tys = lead_tys
      @rest_ty = rest_ty
      @kw_tys = kw_tys # kw_tys should be {:key1 => Type, :key2 => Type, ...} or {nil => Type}
      raise if !kw_tys.is_a?(::Hash)
      @blk_ty = blk_ty
      raise unless blk_ty
    end

    attr_reader :lead_tys, :rest_ty, :kw_tys, :blk_ty

    def globalize(caller_env, visited, depth)
      lead_tys = @lead_tys.map {|ty| ty.globalize(caller_env, visited, depth) }
      rest_ty = @rest_ty.globalize(caller_env, visited, depth) if @rest_ty
      kw_tys = @kw_tys.to_h do |key, ty|
        [key, ty.globalize(caller_env, visited, depth)]
      end
      ActualArguments.new(lead_tys, rest_ty, kw_tys, @blk_ty)
    end

    def limit_size(limit)
      self
    end

    def each_formal_arguments(fargs_format)
      lead_num = fargs_format[:lead_num] || 0
      post_num = fargs_format[:post_num] || 0
      rest_acceptable = !!fargs_format[:rest_start]
      keyword = fargs_format[:keyword]
      kw_rest_acceptable = !!fargs_format[:kwrest]
      opt = fargs_format[:opt]
      #p fargs_format

      # TODO: expand tuples to normal arguments

      # check number of arguments
      if !@rest_ty && lead_num + post_num > @lead_tys.size
        # too less
        yield "wrong number of arguments (given #{ @lead_tys.size }, expected #{ lead_num + post_num })"
        return
      end
      if !rest_acceptable
        # too many
        if opt
          if lead_num + post_num + opt.size - 1 < @lead_tys.size
            yield "wrong number of arguments (given #{ @lead_tys.size }, expected #{ lead_num + post_num }..#{ lead_num + post_num + opt.size - 1})"
            return
          end
        else
          if lead_num + post_num < @lead_tys.size
            yield "wrong number of arguments (given #{ @lead_tys.size }, expected #{ lead_num + post_num })"
            return
          end
        end
      end

      if @rest_ty
        lower_bound = [lead_num + post_num - @lead_tys.size, 0].max
        upper_bound = lead_num + post_num - @lead_tys.size + (opt ? opt.size - 1 : 0) + (rest_acceptable ? 1 : 0)
        rest_elem = @rest_ty.is_a?(Type::Array) ? @rest_ty.elems.squash : Type.any
      else
        lower_bound = upper_bound = 0
      end

      a_kw_tys = @kw_tys.dup
      if keyword
        kw_tys = []
        keyword.each do |kw|
          case
          when kw.is_a?(Symbol) # required keyword
            key = kw
            req = true
          when kw.size == 2 # optional keyword (default value is a literal)
            key, default_ty = *kw
            default_ty = Type.guess_literal_type(default_ty)
            default_ty = default_ty.type if default_ty.is_a?(Type::Literal)
            req = false
          else # optional keyword (default value is an expression)
            key, = kw
            req = false
          end

          if a_kw_tys.key?(key)
            ty = a_kw_tys.delete(key)
          else
            ty = a_kw_tys[nil] || Type.bot
          end
          if ty == Type.bot && req
            yield "no argument for required keywords"
            return
          end
          ty = ty.union(default_ty) if default_ty
          kw_tys << [req, key, ty]
        end
      end
      if kw_rest_acceptable
        if a_kw_tys.key?(nil)
          kw_rest_ty = Type.gen_hash {|h| h[Type.any] = a_kw_tys[nil] }
        else
          kw_rest_ty = Type.gen_hash do |h|
            a_kw_tys.each do |key, ty|
              sym = Type::Symbol.new(key, Type::Instance.new(Type::Builtin[:sym]))
              h[sym] = ty
            end
          end
        end
      end
      #if @kw_tys
      #  yield "passed a keyword to non-keyword method"
      #end

      (lower_bound .. upper_bound).each do |rest_len|
        aargs = @lead_tys + [rest_elem] * rest_len
        lead_tys = aargs.shift(lead_num)
        lead_tys << rest_elem until lead_tys.size == lead_num
        post_tys = aargs.pop(post_num)
        post_tys.unshift(rest_elem) until post_tys.size == post_num
        start_pcs = [0]
        if opt
          tmp_opt = opt[1..]
          opt_tys = []
          until aargs.empty? || tmp_opt.empty?
            opt_tys << aargs.shift
            start_pcs << tmp_opt.shift
          end
        end
        if rest_acceptable
          acc = aargs.inject {|acc, ty| acc.union(ty) }
          acc = acc ? acc.union(rest_elem) : rest_elem if rest_elem
          acc ||= Type.bot
          rest_ty = acc
          aargs.clear
        end
        if !aargs.empty?
          yield "wrong number of arguments (given #{ @lead_tys.size }, expected #{ lead_num + post_num })"
          return
        end
        yield FormalArguments.new(lead_tys, opt_tys, rest_ty, post_tys, kw_tys, kw_rest_ty, @blk_ty), start_pcs
      end
    end

    def consistent_with_method_signature?(msig, subst)
      aargs = @lead_tys.dup

      # aargs: lead_tys, rest_ty
      # msig: lead_tys, opt_tys, rest_ty, post_tys
      if @rest_ty
        lower_bound = [0, msig.lead_tys.size + msig.post_tys.size - aargs.size].max
        upper_bound = [0, lower_bound + msig.opt_tys.size].max
        (lower_bound..upper_bound).each do |n|
          tmp_aargs = ActualArguments.new(@lead_tys + [@rest_ty] * n, nil, @kw_tys, @blk_ty)
          if tmp_aargs.consistent_with_method_signature?(msig, subst) # XXX: wrong subst handling in the loop!
            return true
          end
        end
        return false
      end

      if msig.rest_ty
        return false if aargs.size < msig.lead_tys.size + msig.post_tys.size
        aargs.shift(msig.lead_tys.size).zip(msig.lead_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
        aargs.pop(msig.post_tys.size).zip(msig.post_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
        msig.opt_tys.each do |farg|
          aarg = aargs.shift
          return false unless aarg.consistent?(farg, subst)
        end
        aargs.each do |aarg|
          return false unless aarg.consistent?(msig.rest_ty, subst)
        end
      else
        return false if aargs.size < msig.lead_tys.size + msig.post_tys.size
        return false if aargs.size > msig.lead_tys.size + msig.post_tys.size + msig.opt_tys.size
        aargs.shift(msig.lead_tys.size).zip(msig.lead_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
        aargs.pop(msig.post_tys.size).zip(msig.post_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
        aargs.zip(msig.opt_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
      end
      # XXX: msig.keyword_tys

      case msig.blk_ty
      when Type::TypedProc
        return false if @blk_ty == Type.nil
      when Type.nil
        return false if @blk_ty != Type.nil
      when Type::Any
      else
        raise "unknown typo of formal block signature"
      end
      true
    end

    def to_block_signature
      BlockSignature.new(@lead_tys, [], @rest_ty, @blk_ty)
    end
  end
end
