def gvar_test
  $gvar
end

class Foo
  def const_test
    CONST
  end

  def ivar_test
    @ivar
  end

  def cvar_test
    @@cvar
  end

  def self.cvar_test2
    @@cvar
  end
end
