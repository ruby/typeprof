# Ruby Type Profiler

WARNING: Use Ruby 2.7.1 or master

## Setup

```
git clone https://github.com/mame/ruby-type-profiler.git
git submodule init
bundle install
ruby exe/type-profiler target.rb
```

## Demo

```
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
$ bundle exec ruby exe/type-profiler test.rb
# Classes
class Object
  def foo : (Integer) -> String?
end
```

## Document

[English](doc/doc.md) / [日本語](doc/doc.ja.md)

## Todo

Contribution is welcome!

* Reorganize the test suite (by using minitest framework or something)
* Design and implement an reasonable CLI UI (nothing is configurable currently)
* Release a gem
* Continue to perform an experiment
