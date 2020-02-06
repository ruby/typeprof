module TypeProfiler
  class Type # or AbstractValue
    # This is a type for global interface, e.g., TypedISeq.
    # Do not insert Array type to local environment, stack, etc.
    class Array < Type
      def initialize(elems, base_type)
        raise unless elems.is_a?(Array::Elements)
        @elems = elems # Array::Elements
        @base_type = base_type
        # XXX: need infinite recursion
      end

      attr_reader :elems, :base_type

      def inspect
        "Type::Array#{ @elems.inspect }"
        #@base_type.inspect
      end

      def screen_name(scratch)
        @elems.screen_name(scratch)
      end

      def globalize(env, visited)
        self
      end

      def localize(env, alloc_site)
        env, elems = @elems.localize(env, alloc_site)
        env, ty = env.deploy_array_type(alloc_site, elems, @base_type)
      end

      def get_method(mid, scratch)
        raise
      end

      class Elements
        include Utils::StructuralEquality

        def initialize(lead_tys, rest_ty = Type.bot)
          raise unless lead_tys.all? {|ty| ty.is_a?(Type) }
          raise unless rest_ty.is_a?(Type)
          @lead_tys, @rest_ty = lead_tys, rest_ty
        end

        attr_reader :lead_tys, :rest_ty

        def globalize(env, visited)
          lead_tys = []
          @lead_tys.each do |ty|
            lead_tys << ty.globalize(env, visited)
          end
          rest_ty = @rest_ty&.globalize(env, visited)
          Elements.new(lead_tys, rest_ty)
        end

        def localize(env, alloc_site)
          lead_tys = @lead_tys.map.with_index do |ty, i|
            alloc_site2 = alloc_site.add_id(i)
            env, ty = ty.localize(env, alloc_site2)
            ty
          end
          alloc_site_rest = alloc_site.add_id(:rest)
          env, rest_ty = @rest_ty.localize(env, alloc_site_rest)
          return env, Elements.new(lead_tys, rest_ty)
        end

        def screen_name(scratch)
          if ENV["TP_DUMP_RAW_ELEMENTS"] || @rest_ty == Type.bot
            s = @lead_tys.map do |ty|
              ty.screen_name(scratch)
            end
            s << "*" + @rest_ty.screen_name(scratch) if @rest_ty != Type.bot
            return "[#{ s.join(", ") }]"
          end

          "Array[#{ squash.screen_name(scratch) }]"
        end

        def pretty_print(q)
          q.group(9, "Elements[", "]") do
            q.seplist(@lead_tys + [@rest_ty]) do |elem|
              q.pp elem
            end
          end
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
        @base_type = base_type
      end

      attr_reader :id, :base_type

      def inspect
        "Type::LocalArray[#{ @id }]"
      end

      def screen_name(scratch)
        #raise "LocalArray must not be included in signature"
        "LocalArray!"
      end

      def globalize(env, visited)
        if visited[self]
          Type.any
        else
          visited[self] = true
          elems = env.get_array_elem_types(@id)
          if elems
            elems = elems.globalize(env, visited)
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

      def consistent?(other)
        raise "must not be used"
      end
    end


    class Hash < Type
      def initialize(elems, base_type)
        @elems = elems
        @base_type = base_type
      end

      attr_reader :elems, :base_type

      def inspect
        "Type::Hash#{ @elems.inspect }"
      end

      def screen_name(scratch)
        @elems.screen_name(scratch)
      end

      def globalize(env, visited)
        self
      end

      def localize(env, alloc_site)
        env, elems = @elems.localize(env, alloc_site)
        env, ty = env.deploy_hash_type(alloc_site, elems, @base_type)
      end

      def get_method(mid, scratch)
        raise
      end

      class Elements
        include Utils::StructuralEquality

        def initialize(map_tys)
          raise unless map_tys.all? {|k_ty, v_ty| k_ty.is_a?(Type) && v_ty.is_a?(Type) }
          @map_tys = map_tys
        end

        attr_reader :map_tys

        def globalize(env, visited)
          map_tys = {}
          @map_tys.each do |k_ty, v_ty|
            k_ty = k_ty.globalize(env, visited)
            v_ty = v_ty.globalize(env, visited)
            if map_tys[k_ty]
              map_tys[k_ty] = map_tys[k_ty].union(v_ty)
            else
              map_tys[k_ty] = v_ty
            end
          end
          Elements.new(map_tys)
        end

        def localize(env, alloc_site)
          map_tys = @map_tys.to_h do |k_ty, v_ty|
            alloc_site2 = alloc_site.add_id(k_ty)
            env, k_ty = k_ty.localize(env, alloc_site2.add_id(:key))
            env, v_ty = v_ty.localize(env, alloc_site2.add_id(:val))
            [k_ty, v_ty]
          end
          return env, Elements.new(map_tys)
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
              group do
                q.pp k_ty
                q.text '=>'
                q.group(1) do
                  q.breakable ''
                  q.pp v
                end
              end
            end
          end
        end

        def [](key_ty)
          val_ty = Type.bot
          @map_tys.each do |k_ty, v_ty|
            if k_ty.consistent?(key_ty)
              val_ty = val_ty.union(v_ty)
            end
          end
          val_ty
        end

        def update(idx, ty)
          raise NotImplementedError
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

        def union(other)
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

      def globalize(env, visited)
        if visited[self]
          Type.any
        else
          visited[self] = true
          elems = env.get_hash_elem_types(@id)
          if elems
            elems = elems.globalize(env, visited)
          else
            elems = Hash::Elements.new({Type.any => Type.any})
          end
          Hash.new(elems, @base_type)
        end
      end

      def get_method(mid, scratch)
        @base_type.get_method(mid, scratch)
      end

      def consistent?(other)
        raise "must not be used"
      end
    end
  end
end
