## update: test0.rb
class C
end

class D
  class E < C
  end
end

## assert: test0.rb
class C
end
class D
  class D::E < C
  end
end

## update: test1.rb
class D
  class C # Defining D::C changes the superclass of D::E from ::C to D::C
  end
end

## assert: test0.rb
class C
end
class D
  class D::E < D::C
  end
end

## update: test1.rb
class D
  # Removing D::C restores the superclass of D::E back to ::C
end

## assert: test0.rb
class C
end
class D
  class D::E < C
  end
end

