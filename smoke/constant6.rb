class Foo
  # TODO: This assignment should be warned as inconsistent with RBS
  A = "string"
end

__END__
# Classes
class Foo
  A: Integer | String
end
