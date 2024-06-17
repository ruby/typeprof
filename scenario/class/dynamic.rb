## update
module 1::C
end

class 1::C
end

## diagnostics
(1,0)-(2,3): TypeProf cannot analyze a non-static module
(4,0)-(5,3): TypeProf cannot analyze a non-static class

## update
Class.new do
  class << self
    def foo = :ok
  end
end

## diagnostics
(2,2)-(4,5): TypeProf cannot analyze a non-static class
