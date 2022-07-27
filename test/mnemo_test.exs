defmodule MnemoTest do
  use ExUnit.Case
  doctest Mnemo

  test "greets the world" do
    assert Mnemo.hello() == :world
  end
end
