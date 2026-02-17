## update
$gv ||= :GVar

class C
  D ||= :ConstD
  @@cv ||= :CV0
  def get_lv
    lv = nil
    lv ||= :LVar
    lv
  end
  def set_iv
    @iv ||= :IVar
  end
  def get_iv = @iv
  def get_gv = $gv
  def set_cv
    @@cv ||= :CV1
  end
  def get_cv = @@cv
  def get_index_asgn
    ary = [nil]
    ary[0] ||= :IndexAsgn
    ary
  end
  def get_attr_asgn
    self.test_attr ||= :AttrAsgn
  end
  def test_attr = nil
  def test_attr=(x)
    x
  end
end
C::E ||= :ConstE

## diagnostics
## assert
class C
  D: :ConstD
  def get_lv: -> :LVar
  def set_iv: -> :IVar
  def get_iv: -> :IVar
  def get_gv: -> :GVar
  def set_cv: -> (:CV0 | :CV1)
  def get_cv: -> (:CV0 | :CV1)
  def get_index_asgn: -> [:IndexAsgn?]
  def get_attr_asgn: -> :AttrAsgn
  def test_attr: -> nil
  def test_attr=: (:AttrAsgn) -> :AttrAsgn
end
C::E: :ConstE
