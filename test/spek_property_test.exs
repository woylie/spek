defmodule SpekPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Spek.Checks

  @context_keys [:a, :b, :c, :d, :e]

  defp expression do
    tree(one_of([leaf(), factorable()]), fn child ->
      one_of([
        map(list_of(child, max_length: 4), &Spek.all_of/1),
        map(list_of(child, max_length: 4), &Spek.any_of/1),
        map(child, &Spek.negate/1),
        child
      ])
    end)
  end

  defp leaf do
    one_of([
      map(
        member_of([true, false, :ok, :error, {:ok, "good"}, {:error, "bad"}]),
        &Spek.literal/1
      ),
      map(
        member_of(@context_keys),
        &Spek.check(Checks, :from_bool, [{:ctx, &1}])
      )
    ])
  end

  defp factorable do
    map(tuple({leaf(), leaf(), leaf(), boolean()}), fn
      {shared, left, right, true} ->
        Spek.all_of([
          Spek.any_of([shared, left]),
          Spek.any_of([shared, right])
        ])

      {shared, left, right, false} ->
        Spek.any_of([
          Spek.all_of([shared, left]),
          Spek.all_of([shared, right])
        ])
    end)
  end

  defp context do
    fixed_map(Map.new(@context_keys, &{&1, boolean()}))
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
