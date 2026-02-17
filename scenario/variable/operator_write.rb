## update
$gv = 0
$gv += 1
class C
  D = 0
  D += 1
  @@cvar = ""
  @@cvar += "1"
  def get_lv
    lv = 0
    lv += 1
    lv
  end
  def set_iv
    @iv = 0
    @iv += 1
  end
  def get_iv = @iv
  def get_gv = $gv
  def set_cv
    @@cvar = ""
    @@cvar += "hoge"
  end
  def get_cv = @@cvar
  def get_index_asgn
    ary = [0]
    ary[0] += 1
    ary
  end
  def get_attr_asgn
    self.test_attr += 1
  end
  def test_attr = 0
  def test_attr=(x)
    x
  end
end
C::E = 0
C::E += 1


## diagnostics
## assert
class C
  D: Integer
  D: Integer
  def get_lv: -> Integer
  def set_iv: -> Integer
  def get_iv: -> Integer
  def get_gv: -> Integer
  def set_cv: -> String
  def get_cv: -> String
  def get_index_asgn: -> [Integer]
  def get_attr_asgn: -> Integer
  def test_attr: -> Integer
  def test_attr=: (Integer) -> Integer
end
C::E: Integer
C::E: Integer
