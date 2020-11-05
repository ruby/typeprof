# TypeProf: A type analysis tool for Ruby code based on abstract interpretation

## Synopsis

```sh
gem install typeprof
typeprof app.rb
```

## Demo

```rb
# test.rb
def foo(x)
  if x > 10
    x.to_s
  else
    nil
  end
end

foo(42)
```

```
$ typeprof test.rb
# Classes
class Object
  def foo : (Integer) -> String?
end
```

## Documentation

[English](doc/doc.md) / [日本語](doc/doc.ja.md)

## Playground

Accessing below URL, you can try to use typeprof gem on Web.

https://mame.github.io/typeprof-playground/
