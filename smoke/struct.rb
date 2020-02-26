# tentative
class Foo < Struct.new(:a)
end
__END__
# Errors
smoke/struct.rb:2: [warning] superclass is an instance; Object is used instead
# Classes
