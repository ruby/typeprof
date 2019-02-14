def foo
  x = nil
  [1, "str"].each do |y|
    x = y
  end
  x
end

foo

__END__
Object#foo :: () -> (NilClass | String | Integer)
