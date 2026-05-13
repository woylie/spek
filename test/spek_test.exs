defmodule SpekTest do
  use ExUnit.Case

  alias Spek.Check
  alias Spek.Checks

  doctest Spek, import: true

  describe "eval/2" do
    test "evaluates expression without context and returns boolean" do
      assert Spek.eval(%Check{
               module: Checks,
               fun: :return_arg,
               args: [:ok]
             }) == %Check{
               module: Checks,
               fun: :return_arg,
               args: [:ok],
               result: :ok,
               satisfied?: true
             }
    end

    test "evaluates expression with context and returns boolean" do
      assert Spek.eval(
               %Check{
                 module: Checks,
                 fun: :return_arg,
                 args: [{:ctx, :result}]
               },
               result: :ok
             ) == %Check{
               module: Checks,
               fun: :return_arg,
               args: [{:ctx, :result}],
               result: :ok,
               satisfied?: true
             }
    end
  end

  describe "eval?/2" do
    test "evaluates expression without context and returns boolean" do
      assert Spek.eval?(%Check{
               module: Checks,
               fun: :return_arg,
               args: [:ok]
             }) == true
    end

    test "evaluates expression with context and returns boolean" do
      assert Spek.eval?(
               %Check{
                 module: Checks,
                 fun: :return_arg,
                 args: [{:ctx, :result}]
               },
               result: :ok
             ) == true
    end
  end
end
