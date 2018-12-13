# Ruby Type Profiler

WARNING: This program requires ruby-trunk.
WARNING: This implementation is very preliminary.

## Demo

```
def foo(x)
  if x
    42
  else
    "str"
  end
end

foo(true)
foo(false)

# Object#foo :: (Boolean) -> (String | Integer)
```

## Idea

This is a type profiler based on abstract interpretation.
It virtually executes a Ruby program with only type-level information, without value-level one.
...

## TODO

There are many features that are not supported yet, including:

* some instructions of RubyVM
* modules
* break/next/redo
* exception
* meta-programming features (is_a?, send, etc.)
* complex arguments: `(opt=expr, *rest, keyword: expr)`
* performance: type profiling may be very slow
* etc. etc.
