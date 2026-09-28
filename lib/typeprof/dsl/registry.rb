module TypeProf
  module Dsl
    class Registry
      @entries = {}

      class << self
        def register(plugin_class, cpath:, mid:, singleton:)
          key = [cpath, mid, singleton]
          @entries[key] ||= []
          @entries[key] << plugin_class unless @entries[key].include?(plugin_class)
        end

        def apply(genv)
          @entries.each do |(cpath, mid, singleton), plugin_classes|
            me = genv.resolve_method(cpath, singleton, mid)
            if me.builtin
              warn "[TypeProf DSL] Cannot register plugin for #{cpath.join('::')}#{singleton ? '.' : '#'}#{mid} (already has builtin)"
              next
            end
            plugins = plugin_classes.map(&:new)
            me.builtin = build_handler(genv, plugins)
          end
        end

        private

        def build_handler(genv, plugins)
          ->(changes, node, ty, a_args, _ret) do
            scope = Scope.new(genv, changes, node, ty, a_args)
            plugins.each { |plugin| plugin.install(scope) }
            # Return false so MethodCallBox also runs normal RBS resolution;
            # plugins only add side effects, not the receiver's return type.
            false
          end
        end
      end
    end
  end
end
