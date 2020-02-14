# Ruby Type Profiler

WARNING: Use Ruby 2.7.0
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

* Many builtin features: Now working to import the definitions from [ruby-signature](https://github.com/ruby/ruby-signature)
* Module#include
* Exceptions and some control structure (redo, retry, etc.)
* Flow sensitivity
* Meta-programming features (is_a?, send, etc.)
* Requiring .rbs instead of .rb (for some methods of application)
* Performance: type profiling may be very slow
* Test, test, test
* etc. etc.
