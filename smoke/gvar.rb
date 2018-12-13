$foo = 1
$foo = "str"
def log(x); end
log($foo)

__END__
$foo :: Integer | String
Object#log :: (String) -> NilClass
Object#log :: (Integer) -> NilClass
