defmodule Spek.OptimizeResultsTest do
  use ExUnit.Case, async: true

  alias Spek.Checks

  setup do
    a = Spek.check(Checks, :from_result_key, [{:ctx, :a}])
    b = Spek.check(Checks, :from_result_key, [{:ctx, :b}])

    context = %{
      a: %{result: {:error, :reason_a}},
      b: %{result: {:error, :reason_b}}
    }

    truthy = Spek.literal({:ok, :truthy_payload})
    falsy = Spek.literal({:error, :falsy_payload})

    %{a: a, b: b, truthy: truthy, falsy: falsy, context: context}
  end

  defp collected(expression, context) do
    case Spek.eval_collect_all(expression, context) do
      {:ok, results} -> results
      {:error, %Spek.EvaluationError{results: results}} -> results
    end
  end

  defp assert_preserved(expression, context) do
    assert collected(expression, context) ==
             collected(Spek.optimize(expression), context)
  end

  defp assert_removed(expression, context, expected_after) do
    assert collected(expression, context) != expected_after
    assert collected(Spek.optimize(expression), context) == expected_after
  end

  describe "laws that leave the collected results unchanged" do
    test "deduplication", %{a: a, context: context} do
      assert_preserved(Spek.all_of([a, a]), context)
      assert_preserved(Spek.any_of([a, a]), context)
    end

    test "factoring", %{a: a, b: b, context: context} do
      c = Spek.check(Checks, :from_result_key, [{:ctx, :a}])

      assert_preserved(
        Spek.any_of([Spek.all_of(a, b), Spek.all_of(c, b)]),
        context
      )

      assert_preserved(
        Spek.all_of([Spek.any_of(a, b), Spek.any_of(c, b)]),
        context
      )
    end

    test "De Morgan's laws", %{a: a, b: b, context: context} do
      assert_preserved(Spek.negate(Spek.all_of([a, b])), context)
      assert_preserved(Spek.negate(Spek.any_of([a, b])), context)
    end

    test "double negation elimination", %{a: a, context: context} do
      assert_preserved(Spek.negate(Spek.negate(a)), context)
    end

    test "single-child elimination", %{a: a, context: context} do
      assert_preserved(Spek.all_of([a]), context)
      assert_preserved(Spek.any_of([a]), context)
    end

    test "negation of a literal keeps the payload", ctx do
      %{truthy: truthy, falsy: falsy, context: context} = ctx

      assert_preserved(Spek.negate(truthy), context)
      assert_preserved(Spek.negate(falsy), context)

      assert Spek.optimize(Spek.negate(truthy)) ==
               Spek.literal({:error, :truthy_payload})

      assert Spek.optimize(Spek.negate(falsy)) ==
               Spek.literal({:ok, :falsy_payload})
    end

    test "negation maps every result shape", _ do
      pairs = [
        {true, false},
        {false, true},
        {:ok, :error},
        {:error, :ok},
        {{:ok, :v}, {:error, :v}},
        {{:error, :v}, {:ok, :v}}
      ]

      for {result, negated} <- pairs do
        assert Spek.optimize(Spek.negate(Spek.literal(result))) ==
                 Spek.literal(negated)
      end
    end
  end

  describe "laws that remove a sub-expression and its results" do
    test "identity drops the removed literal", ctx do
      %{a: a, falsy: falsy, context: context} = ctx

      assert_removed(Spek.any_of([a, falsy]), context, [:reason_a])
    end

    test "annihilation drops everything", ctx do
      %{a: a, truthy: truthy, falsy: falsy, context: context} = ctx

      assert_removed(Spek.all_of([a, falsy]), context, [])
      assert_removed(Spek.any_of([a, truthy]), context, [])
    end

    test "absorption drops the absorbed branch", %{a: a, b: b, context: context} do
      assert_removed(Spek.any_of([a, Spek.all_of(a, b)]), context, [:reason_a])
      assert_removed(Spek.all_of([a, Spek.any_of(a, b)]), context, [:reason_a])
    end

    test "the complement laws drop everything", %{a: a, context: context} do
      assert_removed(Spek.all_of([a, Spek.negate(a)]), context, [])
      assert_removed(Spek.any_of([a, Spek.negate(a)]), context, [])
    end
  end
end
