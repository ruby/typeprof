require_relative "../helper"
require "timeout"

module TypeProf::Core
  class EnvTest < Test::Unit::TestCase
    def test_get_superclass_of_object_without_declaration
      genv = GlobalEnv.new

      # `class Object < BasicObject` is not loaded yet, so superclass is still nil
      assert_equal(
        [false, genv.resolve_cpath([:BasicObject])],
        genv.get_superclass(false, genv.mod_object),
      )
    end

    def test_each_superclass_of_object_without_declaration
      genv = GlobalEnv.new

      # Emulate the middle of loading the core RBS, where Module already knows
      # its superclass but Object does not yet
      genv.resolve_cpath([:Module]).instance_variable_set(:@superclass, genv.mod_object)

      chain = []
      Timeout.timeout(10) do
        genv.each_superclass(genv.mod_object, false) {|mod, singleton| chain << [mod.cpath, singleton] }
      end

      assert_equal([[[], false], [[:BasicObject], false]], chain)
    end
  end
end
