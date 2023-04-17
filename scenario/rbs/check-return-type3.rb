# update: test0.rb
class C
end
class D
end

# update: test1.rb
class Foo
  #: -> C
  def foo
    D.new
  end
end

# diagnostics: test1.rb
(4,4)-(4,9): expected: C; actual: D

# update: test0.rb
class C
end
class D < C
end

# diagnostics: test1.rb
