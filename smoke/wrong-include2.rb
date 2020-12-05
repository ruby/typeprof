class Foo
end

class Bar
  include Foo
end

__END__
# Errors
smoke/wrong-include2.rb:5: [warning] including something that is not a module

# Classes
class Foo
end

class Bar
end
