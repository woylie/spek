defmodule Spek.Evaluator do
  @moduledoc false

  alias Spek.And
  alias Spek.Check
  alias Spek.Literal
  alias Spek.Not
  alias Spek.Or

  ## non-accumulating

  def evaluate_expression(expr, context \\ [])

  def evaluate_expression(%Literal{satisfied?: satisfied?}, _) do
    satisfied?
  end

  def evaluate_expression(%Check{module: module, fun: fun, args: args}, context) do
    module
    |> apply(fun, replace_args(args, context))
    |> Spek.to_boolean()
  end

  def evaluate_expression(%Not{expression: expression}, context) do
    not evaluate_expression(expression, context)
  end

  def evaluate_expression(%And{children: children}, context) do
    Enum.all?(children, &evaluate_expression(&1, context))
  end

  def evaluate_expression(%Or{children: children}, context) do
    Enum.any?(children, &evaluate_expression(&1, context))
  end

  ## accumulating

  def evaluate_expression_acc(expr, context \\ [])

  def evaluate_expression_acc(%Literal{} = literal, _) do
    literal
  end

  def evaluate_expression_acc(
        %Check{module: module, fun: fun, args: args} = check,
        context
      ) do
    result = apply(module, fun, replace_args(args, context))
    %{check | result: result, satisfied?: Spek.to_boolean(result)}
  end

  def evaluate_expression_acc(
        %Not{expression: expression} = not_expr,
        context
      ) do
    evaluated_expression =
      evaluate_expression_acc(expression, context)

    %{
      not_expr
      | expression: evaluated_expression,
        satisfied?: not evaluated_expression.satisfied?
    }
  end

  def evaluate_expression_acc(
        %And{children: children} = and_,
        context
      ) do
    {satisfied?, evaluated_children} =
      Enum.reduce_while(
        children,
        {true, []},
        &and_reducer(&1, &2, context)
      )

    %{and_ | satisfied?: satisfied?, children: Enum.reverse(evaluated_children)}
  end

  def evaluate_expression_acc(
        %Or{children: children} = or_,
        context
      ) do
    {satisfied?, evaluated_children} =
      Enum.reduce_while(
        children,
        {false, []},
        &any_of_reducer(&1, &2, context)
      )

    %{or_ | satisfied?: satisfied?, children: Enum.reverse(evaluated_children)}
  end

  defp and_reducer(expression, {_, acc}, context) do
    case evaluate_expression_acc(expression, context) do
      %{satisfied?: true} = expr -> {:cont, {true, [expr | acc]}}
      %{satisfied?: false} = expr -> {:halt, {false, [expr | acc]}}
    end
  end

  defp any_of_reducer(expression, {_, acc}, context) do
    case evaluate_expression_acc(expression, context) do
      %{satisfied?: true} = expr -> {:halt, {true, [expr | acc]}}
      %{satisfied?: false} = expr -> {:cont, {false, [expr | acc]}}
    end
  end

  defp replace_args([], _), do: []

  defp replace_args(args, context) do
    Enum.map(args, &replace_arg(&1, context))
  end

  defp replace_arg(:ctx, context), do: context

  defp replace_arg({:ctx, key}, context)
       when is_atom(key) and is_map(context) do
    Map.fetch!(context, key)
  end

  defp replace_arg({:ctx, key}, context) when is_list(context) do
    Keyword.fetch!(context, key)
  end

  defp replace_arg(arg, _), do: arg
end
