# update
class Foo
  def initialize
    @var = nil
  end

  def set_var
    @var = 42
  end

  def run
    if @var
      @var.foo
    end
  end
end

# diagnostics
(12,11)-(12,14): undefined method: Integer#foo