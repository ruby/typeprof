## update
f = -> { undefined_in_arrow }
g = lambda { undefined_in_lambda }

## diagnostics
(1,9)-(1,27): undefined method: Object#undefined_in_arrow
(2,13)-(2,32): undefined method: Object#undefined_in_lambda
