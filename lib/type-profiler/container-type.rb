module TypeProfiler
  class AllocationSite
    include Utils::StructuralEquality

    def initialize(val, parent = nil)
      raise if !val.is_a?(Utils::StructuralEquality) && !val.is_a?(Integer) && !val.is_a?(Symbol)
      @val = val
      @parent = parent
      @_hash ||= (@val.hash ^ @parent.hash)
    end

    attr_reader :val, :parent

    def hash
      @_hash
    end

    def add_id(val)
      AllocationSite.new(val, self)
    end
  end

  class Type # or AbstractValue
    # This is a type for global interface, e.g., TypedISeq.
    # Do not insert Array type to local environment, stack, etc.
    class Array < Type
      def initialize(elems, base_type)
        raise unless elems.is_a?(Array::Elements)
        @elems = elems # Array::Elements
        raise unless base_type
        @base_type = base_type
        # XXX: need infinite recursion
      end

      attr_reader :elems, :base_type

      def inspect
        "Type::Array[#{ @elems.inspect }, base_type: #{ @base_type.inspect }]"
        #@base_type.inspect
      end

      def screen_name(scratch)
        str = @elems.screen_name(scratch)
        if str.start_with?("*")
          str = @base_type.screen_name(scratch) + str[1..]
        end
        str
      end

      def globalize(env, visited, depth)
        return Type.any if depth <= 0
        elems = @elems.globalize(env, visited, depth - 1)
        base_ty = @base_type.globalize(env, visited, depth - 1)
        Array.new(elems, base_ty)
      end

      def localize(env, alloc_site, depth)
        return env, Type.any if depth <= 0
        alloc_site = alloc_site.add_id(:ary)
        env, elems = @elems.localize(env, alloc_site, depth - 1)
        env.deploy_array_type(alloc_site, elems, @base_type)
      end

      def limit_size(limit)
        return Type.any if limit <= 0
        Array.new(@elems.limit_size(limit - 1), @base_type)
      end

      def get_method(mid, scratch)
        raise
      end

      def consistent?(other, subst)
        case other
        when Type::Any then true
        when Type::Var then other.add_subst!(self, subst)
        when Type::Union
          other.types.each do |ty2|
            return true if consistent?(ty2, subst)
          end
        when Type::Array
          @base_type.consistent?(other.base_type, subst) && @elems.consistent?(other.elems, subst)
        else
          self == other
        end
      end

      def substitute(subst, depth)
        return Type.any if depth <= 0
        elems = @elems.substitute(subst, depth - 1)
        Array.new(elems, @base_type)
      end

      class Elements
        include Utils::StructuralEquality

        def initialize(lead_tys, rest_ty = Type.bot)
          raise unless lead_tys.all? {|ty| ty.is_a?(Type) }
          raise unless rest_ty.is_a?(Type)
          @lead_tys, @rest_ty = lead_tys, rest_ty
        end

        attr_reader :lead_tys, :rest_ty

        def to_local_type(id)
          base_ty = Type::Instance.new(Type::Builtin[:ary])
          Type::LocalArray.new(id, base_ty)
        end

        def globalize(env, visited, depth)
          lead_tys = []
          @lead_tys.each do |ty|
            lead_tys << ty.globalize(env, visited, depth)
          end
          rest_ty = @rest_ty&.globalize(env, visited, depth)
          Elements.new(lead_tys, rest_ty)
        end

        def localize(env, alloc_site, depth)
          lead_tys = @lead_tys.map.with_index do |ty, i|
            alloc_site2 = alloc_site.add_id(i)
            env, ty = ty.localize(env, alloc_site2, depth)
            ty
          end
          alloc_site_rest = alloc_site.add_id(:rest)
          env, rest_ty = @rest_ty.localize(env, alloc_site_rest, depth)
          return env, Elements.new(lead_tys, rest_ty)
        end

        def limit_size(limit)
          Elements.new(@lead_tys.map {|ty| ty.limit_size(limit) }, @rest_ty.limit_size(limit))
        end

        def screen_name(scratch)
          if ENV["TP_DUMP_RAW_ELEMENTS"] || @rest_ty == Type.bot
            s = @lead_tys.map do |ty|
              ty.screen_name(scratch)
            end
            s << "*" + @rest_ty.screen_name(scratch) if @rest_ty != Type.bot
            return "[#{ s.join(", ") }]"
          end

          "*[#{ squash.screen_name(scratch) }]"
        end

        def pretty_print(q)
          q.group(9, "Elements[", "]") do
            q.seplist(@lead_tys + [@rest_ty]) do |elem|
              q.pp elem
            end
          end
        end

        def consistent?(other, subst)
          n = [@lead_tys.size, other.lead_tys.size].min
          n.times do |i|
            return false unless @lead_tys[i].consistent?(other.lead_tys[i], subst)
          end
          rest_ty1 = @lead_tys[n..].inject(@rest_ty) {|ty1, ty2| ty1.union(ty2) }
          rest_ty2 = other.lead_tys[n..].inject(other.rest_ty) {|ty1, ty2| ty1.union(ty2) }
          rest_ty1.consistent?(rest_ty2, subst)
        end

        def substitute(subst, depth)
          lead_tys = @lead_tys.map {|ty| ty.substitute(subst, depth) }
          rest_ty = @rest_ty.substitute(subst, depth)
          Elements.new(lead_tys, rest_ty)
        end

        def squash
          @lead_tys.inject(@rest_ty) {|ty1, ty2| ty1.union(ty2) } #.union(Type.nil) # is this needed?
        end

        def [](idx)
          if idx < @lead_tys.size
            @lead_tys[idx]
          elsif @rest_ty == Type.bot
            Type.nil
          else
            @rest_ty
          end
        end

        def update(idx, ty)
          if idx
            if idx < @lead_tys.size
              lead_tys = Utils.array_update(@lead_tys, idx, ty)
              Elements.new(lead_tys, @rest_ty)
            else
              rest_ty = @rest_ty.union(ty)
              Elements.new(@lead_tys, rest_ty)
            end
          else
            lead_tys = @lead_tys.map {|ty1| ty1.union(ty) }
            rest_ty = @rest_ty.union(ty)
            Elements.new(lead_tys, rest_ty)
          end
        end

        def append(ty)
          if @rest_ty == Type.bot
            if @lead_tys.size < 5 # XXX: should be configurable, or ...?
              lead_tys = @lead_tys + [ty]
              Elements.new(lead_tys, @rest_ty)
            else
              Elements.new(@lead_tys, ty)
            end
          else
            Elements.new(@lead_tys, @rest_ty.union(ty))
          end
        end

        def union(other)
          return self if self == other
          raise "Hash::Elements merge Array::Elements" if other.is_a?(Hash::Elements)

          lead_count = [@lead_tys.size, other.lead_tys.size].min
          lead_tys = (0...lead_count).map do |i|
            @lead_tys[i].union(other.lead_tys[i])
          end

          rest_ty = @rest_ty.union(other.rest_ty)
          (@lead_tys[lead_count..-1] + other.lead_tys[lead_count..-1]).each do |ty|
            rest_ty = rest_ty.union(ty)
          end

          Elements.new(lead_tys, rest_ty)
        end

        def take_first(num)
          base_ty = Type::Instance.new(Type::Builtin[:ary])
          if @lead_tys.size >= num
            lead_tys = @lead_tys[0, num]
            rest_ary_ty = Array.new(Elements.new(@lead_tys[num..-1], @rest_ty), base_ty)
            return lead_tys, rest_ary_ty
          else
            lead_tys = @lead_tys.dup
            until lead_tys.size == num
              # .union(Type.nil) is needed for `a, b, c = [42]` to assign nil to b and c
              lead_tys << @rest_ty.union(Type.nil)
            end
            rest_ary_ty = Array.new(Elements.new([], @rest_ty), base_ty)
            return lead_tys, rest_ary_ty
          end
        end

        def take_last(num)
          base_ty = Type::Instance.new(Type::Builtin[:ary])
          if @rest_ty == Type.bot
            if @lead_tys.size >= num
              following_tys = @lead_tys[-num, num]
              rest_ary_ty = Array.new(Elements.new(@lead_tys[0...-num], Type.bot), base_ty)
              return rest_ary_ty, following_tys
            else
              following_tys = @lead_tys[-num, num] || []
              until following_tys.size == num
                following_tys.unshift(Type.nil)
              end
              rest_ary_ty = Array.new(Elements.new([], Type.bot), base_ty)
              return rest_ary_ty, following_tys
            end
          else
            lead_tys = @lead_tys.dup
            last_ty = rest_ty
            following_tys = []
            until following_tys.size == num
              last_ty = last_ty.union(lead_tys.pop) unless lead_tys.empty?
              following_tys.unshift(last_ty)
            end
            rest_ty = lead_tys.inject(last_ty) {|ty1, ty2| ty1.union(ty2) }
            rest_ary_ty = Array.new(Elements.new([], Type.bot), base_ty)
            return rest_ary_ty, following_tys
          end
        end
      end
    end

    # Do not insert Array type to local environment, stack, etc.
    class LocalArray < Type
      def initialize(id, base_type)
        @id = id
        raise unless base_type
        @base_type = base_type
      end

      attr_reader :id, :base_type

      def inspect
        "Type::LocalArray[#{ @id }, base_type: #{ @base_type.inspect }]"
      end

      def screen_name(scratch)
        #raise "LocalArray must not be included in signature"
        "LocalArray!"
      end

      def globalize(env, visited, depth)
        if visited[self] || depth <= 0
          Type.any
        else
          visited[self] = true
          elems = env.get_container_elem_types(@id)
          if elems
            elems = elems.globalize(env, visited, depth - 1)
          else
            # TODO: currently out-of-scope array cannot be accessed
            elems = Array::Elements.new([], Type.any)
          end
          Array.new(elems, @base_type)
        end
      end

      def get_method(mid, scratch)
        @base_type.get_method(mid, scratch)
      end

      def consistent?(other, subst)
        raise "must not be used"
      end
    end


    class Hash < Type
      def initialize(elems, base_type)
        @elems = elems
        raise unless elems
        @base_type = base_type
      end

      attr_reader :elems, :base_type

      def inspect
        "Type::Hash#{ @elems.inspect }"
      end

      def screen_name(scratch)
        @elems.screen_name(scratch)
      end

      def globalize(env, visited, depth)
        return Type.any if depth <= 0
        elems = @elems.globalize(env, visited, depth - 1)
        base_ty = @base_type.globalize(env, visited, depth - 1)
        Hash.new(elems, base_ty)
      end

      def localize(env, alloc_site, depth)
        return env, Type.any if depth <= 0
        alloc_site = alloc_site.add_id(:hash)
        env, elems = @elems.localize(env, alloc_site, depth - 1)
        env.deploy_hash_type(alloc_site, elems, @base_type)
      end

      def limit_size(limit)
        return Type.any if limit <= 0
        Hash.new(@elems.limit_size(limit - 1), @base_type)
      end

      def get_method(mid, scratch)
        raise
      end

      def consistent?(other, subst)
        case other
        when Type::Any then true
        when Type::Var then other.add_subst!(self, subst)
        when Type::Union
          other.types.each do |ty2|
            return true if consistent?(ty2, subst)
          end
        when Type::Hash
          @base_type.consistent?(other.base_type, subst) && @elems.consistent?(other.elems, subst)
        else
          self == other
        end
      end

      def substitute(subst, depth)
        return Type.any if depth <= 0
        elems = @elems.substitute(subst, depth - 1)
        Hash.new(elems, @base_type)
      end

      class Elements
        include Utils::StructuralEquality

        def initialize(map_tys)
          map_tys.each do |k_ty, v_ty|
            raise unless k_ty.is_a?(Type)
            raise unless v_ty.is_a?(Type)
            raise if k_ty.is_a?(Type::Union)
            raise if k_ty.is_a?(Type::LocalArray)
            raise if k_ty.is_a?(Type::LocalHash)
            raise if k_ty.is_a?(Type::Array)
            raise if k_ty.is_a?(Type::Hash)
          end
          @map_tys = map_tys
        end

        attr_reader :map_tys

        def to_local_type(id)
          base_ty = Type::Instance.new(Type::Builtin[:hash])
          Type::LocalHash.new(id, base_ty)
        end

        def globalize(env, visited, depth)
          map_tys = {}
          @map_tys.each do |k_ty, v_ty|
            v_ty = v_ty.globalize(env, visited, depth)
            if map_tys[k_ty]
              map_tys[k_ty] = map_tys[k_ty].union(v_ty)
            else
              map_tys[k_ty] = v_ty
            end
          end
          Elements.new(map_tys)
        end

        def localize(env, alloc_site, depth)
          map_tys = @map_tys.to_h do |k_ty, v_ty|
            alloc_site2 = alloc_site.add_id(k_ty)
            env, v_ty = v_ty.localize(env, alloc_site2, depth)
            [k_ty, v_ty]
          end
          return env, Elements.new(map_tys)
        end

        def limit_size(limit)
          map_tys = {}
          @map_tys.each do |k_ty, v_ty|
            k_ty = k_ty.limit_size(limit)
            v_ty = v_ty.limit_size(limit)
            if map_tys[k_ty]
              map_tys[k_ty] = map_tys[k_ty].union(v_ty)
            else
              map_tys[k_ty] = v_ty
            end
          end
          Elements.new(map_tys)
        end

        def screen_name(scratch)
          s = @map_tys.map do |k_ty, v_ty|
            k = k_ty.screen_name(scratch)
            v = v_ty.screen_name(scratch)
            "#{ k }=>#{ v }"
          end.join(", ")
          "{#{ s }}"
        end

        def pretty_print(q)
          q.group(9, "Elements[", "]") do
            q.seplist(@map_tys) do |k_ty, v_ty|
              q.group do
                q.pp k_ty
                q.text '=>'
                q.group(1) do
                  q.breakable ''
                  q.pp v_ty
                end
              end
            end
          end
        end

        def consistent?(other, subst)
          subst2 = subst.dup
          other.map_tys.each do |k1, v1|
            found = false
            @map_tys.each do |k0, v0|
              subst3 = subst2.dup
              if k0.consistent?(k1, subst3) && v0.consistent?(v1, subst3)
                subst2.replace(subst3)
                found = true
                break
              end
            end
            return false unless found
          end
          subst.replace(subst2)
          true
        end

        def substitute(subst, depth)
          map_tys = {}
          @map_tys.each do |k_ty_orig, v_ty_orig|
            k_ty = k_ty_orig.substitute(subst, depth)
            v_ty = v_ty_orig.substitute(subst, depth)
            k_ty.each_child_global do |k_ty|
              # This is a temporal hack to mitigate type explosion
              k_ty = Type.any if k_ty.is_a?(Type::Array)
              k_ty = Type.any if k_ty.is_a?(Type::Hash)
              if map_tys[k_ty]
                map_tys[k_ty] = map_tys[k_ty].union(v_ty)
              else
                map_tys[k_ty] = v_ty
              end
            end
          end
          Elements.new(map_tys)
        end

        def squash
          all_k_ty, all_v_ty = Type.bot, Type.bot
          @map_tys.each do |k_ty, v_ty|
            all_k_ty = all_k_ty.union(k_ty)
            all_v_ty = all_v_ty.union(v_ty)
          end
          return all_k_ty, all_v_ty
        end

        def [](key_ty)
          val_ty = Type.bot
          @map_tys.each do |k_ty, v_ty|
            if k_ty.consistent?(key_ty, {})
              val_ty = val_ty.union(v_ty)
            end
          end
          val_ty
        end

        def update(idx, ty)
          map_tys = @map_tys.dup
          idx.each_child_global do |idx|
            # This is a temporal hack to mitigate type explosion
            idx = Type.any if idx.is_a?(Type::Array)
            idx = Type.any if idx.is_a?(Type::Hash)

            if map_tys[idx]
              map_tys[idx] = map_tys[idx].union(ty)
            else
              map_tys[idx] = ty
            end
          end
          Elements.new(map_tys)
        end

        def union(other)
          return self if self == other
          raise "Array::Elements merge Hash::Elements" if other.is_a?(Array::Elements)

          map_tys = @map_tys.dup
          other.map_tys.each do |k_ty, v_ty|
            if map_tys[k_ty]
              map_tys[k_ty] = map_tys[k_ty].union(v_ty)
            else
              map_tys[k_ty] = v_ty
            end
          end

          Elements.new(map_tys)
        end
      end
    end

    class LocalHash < Type
      def initialize(id, base_type)
        @id = id
        @base_type = base_type
      end

      attr_reader :id, :base_type

      def inspect
        "Type::LocalHash[#{ @id }]"
      end

      def screen_name(scratch)
        #raise "LocalHash must not be included in signature"
        "LocalHash!"
      end

      def globalize(env, visited, depth)
        if visited[self] || depth <= 0
          Type.any
        else
          visited[self] = true
          elems = env.get_container_elem_types(@id)
          if elems
            elems = elems.globalize(env, visited, depth - 1)
          else
            elems = Hash::Elements.new({Type.any => Type.any})
          end
          Hash.new(elems, @base_type)
        end
      end

      def get_method(mid, scratch)
        @base_type.get_method(mid, scratch)
      end

      def consistent?(other, subst)
        raise "must not be used"
      end
    end
  end
end
