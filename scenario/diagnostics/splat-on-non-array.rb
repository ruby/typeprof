## update
def check
  a = *123 # this calls `to_a` on 123, but the error should be suppressed
end

## diagnostics
