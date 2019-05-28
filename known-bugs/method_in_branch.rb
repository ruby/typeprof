if 1+1
  def foo
  end
  def bar
    foo
    42
  end
else
  def bar
    "str"
  end
end

bar

__END__
Object#bar :: () -> (String | Integer)
Object#foo :: () -> NilClass
