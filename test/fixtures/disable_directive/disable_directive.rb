def check
  Foo.new.accept_int("str") # typeprof:disable
end
