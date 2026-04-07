def check
  # typeprof:ignore:start
  Foo.new.accept_int("str")
  Foo.new.accept_int("str")
  # typeprof:ignore:end
end
