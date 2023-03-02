require "test/unit"
require_relative "../lib/typeprof"

module TypeProf
  class IncrementalTest < Test::Unit::TestCase
    def test_incremental1
      serv = TypeProf::Service.new

      serv.update_file("test0.rb", <<-END)
def foo(x)
  x * x
end
      END

      [:foo].each do |mid|
        serv.genv.get_method_entity([:Object], false, mid).defs.each do |mdef|
          assert_equal("def foo: (untyped) -> untyped", "def #{ mid }: " + mdef.show)
        end
      end

      #serv.show_graph([:Object], :foo)

      serv.update_file("test1.rb", <<-END)


def main(_)
  foo(1)
end
      END

      [:foo].each do |mid|
        serv.genv.get_method_entity([:Object], false, mid).defs.each do |mdef|
          assert_equal("def foo: (Integer) -> Integer", "def #{ mid }: " + mdef.show)
        end
      end
      #serv.show_graph([:Object], :main)

      serv.update_file("test1.rb", <<-END)


def main(_)
  foo("str")
end
      END

      [:foo].each do |mid|
        serv.genv.get_method_entity([:Object], false, mid).defs.each do |mdef|
          assert_equal("def foo: (String) -> untyped", "def #{ mid }: " + mdef.show)
        end
      end
    end

    def test_incremental2
      serv = TypeProf::Service.new

      serv.update_file("test.rb", <<-END)
def foo(x)
  x + 1
end

def main(_)
  foo(2)
end
      END
      
      [:foo].each do |mid|
        serv.genv.get_method_entity([:Object], false, mid).defs.each do |mdef|
          assert_equal("def foo: (Integer) -> Integer", "def #{ mid }: " + mdef.show)
        end
      end
      
      #serv.show_graph([:Object], :foo)
      
      serv.update_file("test.rb", <<-END)
      
def foo(x)
  x + 1.0
end

def main(_)
  foo(2)
end
      END
      
      [:foo].each do |mid|
        serv.genv.get_method_entity([:Object], false, mid).defs.each do |mdef|
          assert_equal("def foo: (Integer) -> Float", "def #{ mid }: " + mdef.show)
        end
      end
    end

    def test_incremental3
      serv = TypeProf::Service.new

      serv.update_file("test.rb", <<-END)
def foo(x)
  x + 1
end

def main(_)
  foo(2)
end
      END
      
      [:foo].each do |mid|
        serv.genv.get_method_entity([:Object], false, mid).defs.each do |mdef|
          assert_equal("def foo: (Integer) -> Integer", "def #{ mid }: " + mdef.show)
        end
      end
      
      #serv.show_graph([:Object], :foo)
      
      serv.update_file("test.rb", <<-END)
      
def foo(x)
  x + 1
end

def main(_)
  foo("str")
end
      END
      
      [:foo].each do |mid|
        serv.genv.get_method_entity([:Object], false, mid).defs.each do |mdef|
          assert_equal("def foo: (String) -> untyped", "def #{ mid }: " + mdef.show)
        end
      end
    end
  end
end