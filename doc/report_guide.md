# How to Report Bugs and Propose Features

Thank you for your interest in improving TypeProf! When reporting a bug or proposing a feature, including a **scenario file** is very helpful (but not mandatory).

## What is a Scenario File?

A scenario file describes TypeProf's behavior — the input code and the expected type inference result. You can find many examples in the [`scenario/`](../scenario/) directory.

## Writing a Scenario File

### Basic pattern

A minimal scenario file has two sections: `## update` (input code) and `## assert` (expected type signatures in [RBS](https://github.com/ruby/rbs) syntax).

```ruby
## update
def foo(n)
  n.to_s
end

foo(42)

## assert
class Object
  def foo: (Integer) -> String
end
```

### Multiple updates

You can include multiple `## update` / `## assert` pairs to test how TypeProf handles code changes:

```ruby
## update
def foo = "symbol#{ 42 }"

## assert
class Object
  def foo: -> String
end

## update
def foo = :"symbol#{ 42 }"

## assert
class Object
  def foo: -> Symbol
end
```

### Diagnostics

Use `## diagnostics` to verify that TypeProf reports type errors at the expected locations:

```ruby
## update
def foo(x)
  x
end

foo(1, 2)

## diagnostics
(5,0)-(5,3): wrong number of arguments (2 for 1)
```

## Running a Scenario File

Run a single scenario file:

```sh
$ ruby tool/scenario_runner.rb path/to/your_scenario.rb
```

Run all tests:

```sh
$ bundle exec rake test
```

## Reporting a Bug

1. Create a scenario file that reproduces the issue.
2. Run it with `ruby tool/scenario_runner.rb your_scenario.rb` to confirm the problem.
3. Open an issue and include:
   - Your TypeProf version (`typeprof --version`)
   - The scenario file content
   - What you expected vs. what actually happened
