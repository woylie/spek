defmodule SpekPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Spek.Checks

  defp expression do
    leaf =
      one_of([
        map(
          member_of([true, false, :ok, :error, {:ok, "good"}, {:error, "bad"}]),
          &Spek.literal/1
        ),
        map(
          member_of([:a, :b, :c]),
          &Spek.check(Checks, :from_bool, [{:ctx, &1}])
        )
      ])

    tree(leaf, fn child ->
      one_of([
        map(list_of(child), &Spek.all_of/1),
        map(list_of(child), &Spek.any_of/1),
        map(child, &Spek.negate/1),
        child
      ])
    end)
  end

  defp context do
    fixed_map(%{a: boolean(), b: boolean(), c: boolean()})
  end

  property "optimize/1 does not change the result of eval?/2" do
    check all expression <- expression(),
              context <- context() do
      assert Spek.eval?(expression, context) ==
               Spek.eval?(Spek.optimize(expression), context)
    end
  end

  property "optimize/1 is idempotent" do
    check all expression <- expression() do
      optimized = Spek.optimize(expression)
      assert Spek.optimize(optimized) == optimized
    end
  end
end
