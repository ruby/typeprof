## update
class C
  D = 1
  D = "str"
end

## assert
class C
  C::D: (Integer | String)
end
