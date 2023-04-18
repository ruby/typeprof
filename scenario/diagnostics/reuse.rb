## update
def foo
  unknown
end

## diagnostics
(2,2)-(2,9): undefined method: Object#unknown

## update
def foo
    # line added
    unknown
end

## diagnostics
(3,4)-(3,11): undefined method: Object#unknown