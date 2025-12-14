## update
# Passing class constants (Singleton types) to methods like `all?`
# should not crash with "unknown type variable" error
[].all?(Array)
[].all?(Hash)

## assert
