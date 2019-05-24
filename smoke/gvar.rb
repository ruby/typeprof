$foo = 1
$foo = "str"
def log(x); end
log($foo)

__END__
$foo :: Integer | String
Object#log :: (Integer) -> NilClass
Object#log :: (String) -> NilClass
