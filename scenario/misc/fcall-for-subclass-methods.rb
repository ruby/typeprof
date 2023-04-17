## update
class C
  def run(n)
    run0(n)
  end

  def run0(_)
    raise "abstract method"
  end
end

class D < C
  def run0(n)
  end
end

C.new.run(1)

## assert
class C
  def run: (Integer) -> nil
  def run0: (Integer) -> bot
end
class D < C
  def run0: (Integer) -> nil
end