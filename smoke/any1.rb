def foo
  x = 1.undefined_method
  x.undefined_method2
end

foo

__END__
smoke/any1.rb:2: [error] undefined method: Integer#undefined_method
Object#foo :: () -> any
