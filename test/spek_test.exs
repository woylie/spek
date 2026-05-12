defmodule SpekTest do
  use ExUnit.Case
  doctest Spek

  test "greets the world" do
    assert Spek.hello() == :world
  end
end
