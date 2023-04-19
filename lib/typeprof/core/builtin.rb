module TypeProf::Core
  class Builtin
    def initialize(genv)
      @genv = genv
    end

    def class_new(changes, node, ty, a_args, ret)
      ty = ty.get_instance_type(@genv)
      recv = Source.new(ty)
      site = CallSite.new(node, @genv, recv, :initialize, a_args, nil, nil, nil, false) # TODO: block
      # site.ret (the return value of initialize) is discarded
      changes.add_edge(Source.new(ty), ret)
      changes.add_site(:class_new, site)
    end

    def proc_call(changes, node, ty, a_args, ret)
      case ty
      when Type::Proc
        if a_args.size == ty.block.f_args.size
          a_args.zip(ty.block.f_args) do |a_arg, f_arg|
            changes.add_edge(a_arg, f_arg)
          end
        end
        changes.add_edge(ty.block.ret, ret)
      else
        puts "??? proc_call"
      end
    end

    def array_aref(changes, node, ty, a_args, ret)
      if a_args.size == 1
        case ty
        when Type::Array
          idx = node.positional_args[0]
          if idx.is_a?(AST::LIT) && idx.lit.is_a?(Integer)
            idx = idx.lit
          else
            idx = nil
          end
          changes.add_edge(ty.get_elem(@genv, idx), ret)
        else
          #puts "??? array_aref"
        end
      else
        #puts "??? array_aref"
      end
    end

    def array_aset(changes, node, ty, a_args, ret)
      if a_args.size == 2
        case ty
        when Type::Array
          val = a_args[1]
          idx = node.positional_args[0]
          if idx.is_a?(AST::LIT) && idx.lit.is_a?(Integer) && ty.get_elem(@genv, idx.lit)
            changes.add_edge(val, ty.get_elem(@genv, idx.lit))
          else
            changes.add_edge(val, ty.get_elem(@genv))
          end
        else
          puts "??? array_aset #{ ty.class }"
        end
      else
        puts "??? array_aset #{ a_args.size }"
      end
    end

    def hash_aref(changes, node, ty, a_args, ret)
      if a_args.size == 1
        case ty
        when Type::Hash
          idx = node.positional_args[0]
          if idx.is_a?(AST::LIT) && idx.lit.is_a?(Symbol)
            idx = idx.lit
          else
            idx = nil
          end
          changes.add_edge(ty.get_value(idx), ret)
        else
          #puts "??? hash_aref 1"
        end
      else
        puts "??? hash_aref 2"
      end
    end

    def hash_aset(changes, node, ty, a_args, ret)
      if a_args.size == 2
        case ty
        when Type::Hash
          val = a_args[1]
          idx = node.positional_args[0]
          if idx.is_a?(AST::LIT) && idx.lit.is_a?(Symbol) && ty.get_value(idx.lit)
            # TODO: how to handle new key?
            changes.add_edge(val, ty.get_value(idx.lit))
          else
            # TODO: literal_pairs will not be updated
            changes.add_edge(val, ty.get_value)
          end
        else
          #puts "??? hash_aset 1 #{ ty.object_id } #{ ty.inspect }"
        end
      else
        puts "??? hash_aset 2"
      end
    end

    def deploy
      {
        class_new: [[:Class], false, :new],
        proc_call: [[:Proc], false, :call],
        array_aref: [[:Array], false, :[]],
        array_aset: [[:Array], false, :[]=],
        hash_aref: [[:Hash], false, :[]],
        hash_aset: [[:Hash], false, :[]=],
      }.each do |key, (cpath, singleton, mid)|
        me = @genv.resolve_method(cpath, singleton, mid)
        me.builtin = method(key)
      end
    end
  end
end