## update
$gv ||= :GVar

class C
  D ||= :ConstD
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
  C::D: :ConstD
  def get_lv: -> :LVar
  def set_iv: -> :IVar
  def get_iv: -> :IVar
  def get_gv: -> :GVar
  def get_index_asgn: -> [:IndexAsgn?]
  def get_attr_asgn: -> :AttrAsgn
  def test_attr: -> nil
  def test_attr=: (:AttrAsgn) -> :AttrAsgn
end
C::E: :ConstE
