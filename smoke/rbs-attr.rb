def read_test_1
  Foo.new.reader_example
end

def read_test_2
  Foo.new.accessor_example
end

def write_test
  Foo.new.writer_example = 1
  Foo.new.writer_example = "str"
  Foo.new.accessor_example = 1
  Foo.new.accessor_example = "str"
end

__END__
# Errors
smoke/rbs-attr.rb:11: [warning] inconsistent assignment to RBS-declared variable
smoke/rbs-attr.rb:13: [warning] inconsistent assignment to RBS-declared variable

# Classes
class Object
  private
  def read_test_1: -> Integer
  def read_test_2: -> Integer
  def write_test: -> String
end

class Foo
# attr_reader reader_example: Integer
# attr_writer writer_example: Integer
# attr_accessor accessor_example: Integer
end
