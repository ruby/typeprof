class Foo
  def as_json(options = nil)
    to_s
  end
end
__END__
# Errors
smoke/rbs-remove-rest.rb:2: [error] RBS says that a rest argument is accepted, but the method definition does not accept one

# Classes
