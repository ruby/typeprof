## update: test.rb
def check_interpolation(x)
end

def check(x)
  case x
  in 1
    :int
  in 1.0
    :float
  in 1r
    :rational
  in 1i
    :complex
  in "foo"
    :string
  in "foo#{ check_interpolation(:ok_str) }"
    :interpolated_string
  in :foo
    :symbol
  in :"foo#{ check_interpolation(:ok_sym) }"
    :interpolated_symbol
  in nil
    :nil
  in false
    :false
  in true
    :false
  in __FILE__
    :FILE
  in __LINE__
    :LINE
  in __ENCODING__
    :ENCODING
  in %w[foo bar]
    :w_lit
  else
    :zzz
  end
end

check(1)
check(:AAA)

## assert
class Object
  def check_interpolation: (:ok_str | :ok_sym) -> nil
  def check: (:AAA | Integer) -> (:ENCODING | :FILE | :LINE | :complex | :false | :float | :int | :interpolated_string | :interpolated_symbol | :nil | :rational | :string | :symbol | :w_lit | :zzz)
end
