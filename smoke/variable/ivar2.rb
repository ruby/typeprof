# update
class C
end

class D < C
  def foo = (@x = :D)
  def x = @x
end

class E < D
end

class F < E
end

class G < F
end

# assert
class C
end
class D < C
  def foo: -> :D
  def x: -> :D
end
class E < D
end
class F < E
end
class G < F
end

# update
class C
end

class D < C
  def foo = (@x = :D)
  def x = @x
end

class E < D
end

class F < E
end

class G < F
  def foo = (@x = :G)
end

# assert
class C
end
class D < C
  def foo: -> :D
  def x: -> (:D | :G)
end
class E < D
end
class F < E
end
class G < F
  def foo: -> :G
end

# update
class C
end

class D < C
  def foo = (@x = :D)
  def x = @x
end

class E < D
  def foo = (@x = :E)
end

class F < E
end

class G < F
  def foo = (@x = :G)
end

# assert
class C
end
class D < C
  def foo: -> :D
  def x: -> (:D | :E | :G)
end
class E < D
  def foo: -> :E
end
class F < E
end
class G < F
  def foo: -> :G
end

# update
class C
end

class D < C
  def foo = (@x = :D)
  def x = @x
end

class E < D
end

class F < E
end

class G < F
  def foo = (@x = :G)
end

# assert
class C
end
class D < C
  def foo: -> :D
  def x: -> (:D | :G)
end
class E < D
end
class F < E
end
class G < F
  def foo: -> :G
end

# update
class C
end

class D < C
  def foo = (@x = :D)
  def x = @x
end

class E < D
end

class F < E
  def foo = (@x = :F)
end

class G < F
  def foo = (@x = :G)
end

# assert
class C
end
class D < C
  def foo: -> :D
  def x: -> (:D | :F | :G)
end
class E < D
end
class F < E
  def foo: -> :F
end
class G < F
  def foo: -> :G
end

# update
class C
end

class D < C
  def foo = (@x = :D)
  def x = @x
end

class E < D
end

class F < E
end

class G < F
  def foo = (@x = :G)
end

# assert
class C
end
class D < C
  def foo: -> :D
  def x: -> (:D | :G)
end
class E < D
end
class F < E
end
class G < F
  def foo: -> :G
end

# update
class C
end

class D < C
  def foo = (@x = :D)
  def x = @x
end

class E < D
end

class F < E
  def foo = (@x = :F)
end

class G < F
  def foo = (@x = :G)
end

# assert
class C
end
class D < C
  def foo: -> :D
  def x: -> (:D | :F | :G)
end
class E < D
end
class F < E
  def foo: -> :F
end
class G < F
  def foo: -> :G
end

# update
class C
end

class D < C
  def foo = (@x = :D)
  def x = @x
end

class E < D
end

class F < E
  def foo = (@x = :F)
end

class G < F
end

# assert
class C
end
class D < C
  def foo: -> :D
  def x: -> (:D | :F)
end
class E < D
end
class F < E
  def foo: -> :F
end
class G < F
end