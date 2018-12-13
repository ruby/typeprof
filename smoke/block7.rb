def foo
  yield
end

any = undefined_method
foo(&any)

foo(&1)

__END__
smoke/block7.rb:5: [error] undefined method: Object#undefined_method
smoke/block7.rb:2: [warning] block is any
smoke/block7.rb:8: [error] wrong argument type Integer<1> (expected Proc)
Object#foo :: () -> any
