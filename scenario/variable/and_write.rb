## update
$gv = :GVar0
$gv &&= :GVar

class C
  D &&= :ConstD
  @@cv &&= :CV0
  def get_lv
    lv = :LVar0
    lv &&= :LVar
    lv
  end
  def set_iv
    @iv = :IVar0
    @iv &&= :IVar
  end
  def get_iv = @iv
  def get_gv = $gv
  def set_cv
    @@cv = :CV
  end
  def get_cv = @@cv
  def get_index_asgn
    ary = [:IndexAsgn0]
    ary[0] &&= :IndexAsgn
    ary
  end
  def get_attr_asgn
    self.test_attr &&= :AttrAsgn
  end
  def test_attr = :AttrAsgn0
  def test_attr=(x)
    x
  end
end
C::E &&= :ConstE

## diagnostics
## assert
class C
  C::D: :ConstD
  def get_lv: -> (:LVar | :LVar0)
  def set_iv: -> (:IVar | :IVar0)
  def get_iv: -> (:IVar | :IVar0)
  def get_gv: -> (:GVar | :GVar0)
  def set_cv: -> :CV
  def get_cv: -> (:CV | :CV0)
  def get_index_asgn: -> [:IndexAsgn | :IndexAsgn0]
  def get_attr_asgn: -> (:AttrAsgn | :AttrAsgn0)
  def test_attr: -> :AttrAsgn0
  def test_attr=: (:AttrAsgn | :AttrAsgn0) -> (:AttrAsgn | :AttrAsgn0)
end
C::E: :ConstE
