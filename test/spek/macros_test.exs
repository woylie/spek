defmodule Spek.MacrosTest do
  use ExUnit.Case

  alias __MODULE__.Checks
  alias Spek.Check

  defmodule Checks do
    import Spek.Macros

    build_check(:existing_fun, [{:ctx, :state}, :active])
  end

  describe "build_check/2" do
    test "defines a function that returns a check struct" do
      assert Checks.existing_fun_check() == %Check{
               args: [{:ctx, :state}, :active],
               fun: :existing_fun,
               module: Spek.MacrosTest.Checks
             }
    end
  end
end
