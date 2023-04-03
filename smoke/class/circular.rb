# update
class A < B
end

class B < A
end

module M
  include M
end

# assert
class A < B
end
class B < A
end
module M
end