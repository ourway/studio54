defmodule Studio54Test do
  use ExUnit.Case
  doctest Studio54

  test "greets the world" do
    assert Studio54.hello() == :world
  end
end
