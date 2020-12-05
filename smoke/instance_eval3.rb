:foo.instance_eval do
  @foo = 1
end

__END__
# Classes
class Symbol
  @foo : Integer
end
