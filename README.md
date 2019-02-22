# Ruby Type Profiler

WARNING: This program requires ruby-trunk.
WARNING: This implementation is very preliminary.

## Demo

```
# test.rb
def foo(x)
  if x > 10
    x.to_s
  else
    x.boo()
    x + 42
  end
end

foo(42)
```

```
$ exe/type-profiler test.rb
test.rb:6: [error] undefined method: Integer#boo
test.rb:7: [error] failed to resolve overload: Integer#+
Object#foo :: (Integer) -> String
```

## TODO

There are many features that are not supported yet or incompletely:

* some instructions of RubyVM
* container types (generics)
* modules
* break/next/redo
* exception
* meta-programming features (is_a?, send, etc.)
* complex arguments: `(opt=expr, *rest, keyword: expr)`
* performance: type profiling may be very slow
* etc. etc.
