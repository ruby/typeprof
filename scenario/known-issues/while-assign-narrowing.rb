## update
# `if (y = x)` narrows y (scenario/flow/if_assign.rb) and `while x` narrows x
# (scenario/flow/while.rb), but an assignment in a while condition does not.
def check(ary)
  while (x = ary.pop)
    return x
  end
  :none
end

check(["str"])

## assert
class Object
  def check: ([String]) -> (:none | String)
end

## update
def each_entry
  entries = ["str"]
  while entry = entries.pop
    yield entry
  end
end

## assert
class Object
  def each_entry: { (String) -> untyped } -> nil
end
