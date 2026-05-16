defmodule Spek do
  @moduledoc """
  Documentation for `Spek`.
  """

  alias Spek.AllOf
  alias Spek.AnyOf
  alias Spek.Check
  alias Spek.EvaluationError
  alias Spek.Literal
  alias Spek.Not

  @type expression :: AllOf.t() | AnyOf.t() | Check.t() | Literal.t() | Not.t()

  @type context :: term

  @type truthy :: true | :ok | {:ok, term}
  @type falsy :: false | :error | {:error, term}
  @type result :: truthy | falsy

  ## Builders

  @doc """
  Builds an expression that requires all children to be true.

  ## Example

      iex> all_of([check(MyModule, :check_a, []), check(MyModule, :check_b, [])])
      %Spek.AllOf{
        children: [
          %Spek.Check{module: MyModule, fun: :check_a, args: []},
          %Spek.Check{module: MyModule, fun: :check_b, args: []}
        ]
      }
  """
  @doc type: :builder
  @spec all_of([expression]) :: AllOf.t()
  def all_of(children) when is_list(children) do
    %AllOf{children: children}
  end

  @doc """
  Builds an expression that requires both children to be true.

  ## Example

      iex> all_of(check(MyModule, :check_a, []), check(MyModule, :check_b, []))
      %Spek.AllOf{
        children: [
          %Spek.Check{module: MyModule, fun: :check_a, args: []},
          %Spek.Check{module: MyModule, fun: :check_b, args: []}
        ]
      }
  """
  @doc type: :builder
  @spec all_of(expression, expression) :: AllOf.t()
  def all_of(a, b) do
    %AllOf{children: [a, b]}
  end

  @doc """
  Builds an expression that requires at least one child to be true.

  ## Example

      iex> any_of([check(MyModule, :check_a, []), check(MyModule, :check_b, [])])
      %Spek.AnyOf{
        children: [
          %Spek.Check{module: MyModule, fun: :check_a, args: []},
          %Spek.Check{module: MyModule, fun: :check_b, args: []}
        ]
      }
  """
  @doc type: :builder
  @spec any_of([expression]) :: AnyOf.t()
  def any_of(children) when is_list(children) do
    %AnyOf{children: children}
  end

  @doc """
  Builds an expression that requires at least one child to be true.

  ## Example

      iex> any_of(check(MyModule, :check_a, []), check(MyModule, :check_b, []))
      %Spek.AnyOf{
        children: [
          %Spek.Check{module: MyModule, fun: :check_a, args: []},
          %Spek.Check{module: MyModule, fun: :check_b, args: []}
        ]
      }
  """
  @doc type: :builder
  @spec any_of(expression, expression) :: AnyOf.t()
  def any_of(a, b) do
    %AnyOf{children: [a, b]}
  end

  @doc """
  Builds a check.

  ## Example

      iex> check(MyModule, :check_a, [0])
      %Spek.Check{module: MyModule, fun: :check_a, args: [0]}
  """
  @doc type: :builder
  @spec check(module, fun, Check.args()) :: Check.t()
  def check(module, fun, args) do
    %Check{module: module, fun: fun, args: args}
  end

  @doc """
  Builds an expression that is always false. 

  ## Example

      iex> fail()
      %Spek.Literal{result: false, satisfied?: false}
      
      iex> fail(:error)
      %Spek.Literal{result: :error, satisfied?: false}
      
      iex> fail({:error, :some_reason})
      %Spek.Literal{result: {:error, :some_reason}, satisfied?: false}
  """
  @doc type: :builder
  @spec fail(falsy) :: Literal.t()
  def fail(result \\ false) do
    %Literal{result: result, satisfied?: false}
  end

  @doc """
  Builds an expression that always evaluates to the same value.

  ## Examples

      iex> literal(true)
      %Spek.Literal{result: true, satisfied?: true}
      
      iex> literal(:ok)
      %Spek.Literal{result: :ok, satisfied?: true}

      iex> literal({:ok, "value"})
      %Spek.Literal{result: {:ok, "value"}, satisfied?: true}

      iex> literal(false)
      %Spek.Literal{result: false, satisfied?: false}
      
      iex> literal(:error)
      %Spek.Literal{result: :error, satisfied?: false}
      
      iex> literal({:error, :some_reason})
      %Spek.Literal{result: {:error, :some_reason}, satisfied?: false}
  """
  @doc type: :builder
  @spec literal(result) :: Literal.t()
  def literal(result) do
    %Literal{result: result, satisfied?: to_boolean(result)}
  end

  @doc """
  Builds an expression that evaluates to true unless both children are true.

  ## Example

      iex> nand(check(MyModule, :check_a, []), check(MyModule, :check_b, []))
      %Spek.Not{
        expression: %Spek.AllOf{
          children: [
            %Spek.Check{module: MyModule, fun: :check_a, args: []},
            %Spek.Check{module: MyModule, fun: :check_b, args: []}
          ]
        }
      }
  """
  @doc type: :builder
  @spec nand(expression, expression) :: expression
  def nand(a, b) do
    negate(all_of(a, b))
  end

  @doc """
  Negates the given expression.

  ## Examples

      iex> negate(literal(true))
      %Spek.Not{expression: %Spek.Literal{result: true, satisfied?: true}}

      iex> negate(check(MyModule, :check_a, []))
      %Spek.Not{
        expression: %Spek.Check{module: MyModule, fun: :check_a, args: []}
      }
  """
  @doc type: :builder
  @spec negate(expression) :: Not.t()
  def negate(expression) do
    %Not{expression: expression}
  end

  @doc """
  Builds an expression that requires all of its children to be false.

  ## Example

      iex> none([check(MyModule, :check_a, []), check(MyModule, :check_b, [])])
      %Spek.Not{
        expression: %Spek.AnyOf{
          children: [
            %Spek.Check{module: MyModule, fun: :check_a, args: []},
            %Spek.Check{module: MyModule, fun: :check_b, args: []}
          ]
        }
      }
  """
  @doc type: :builder
  @spec none([expression]) :: expression
  def none(children) when is_list(children) do
    negate(any_of(children))
  end

  @doc """
  Builds an expression that evaluates to true if both children are false.

  ## Example

      iex> nor(check(MyModule, :check_a, []), check(MyModule, :check_b, []))
      %Spek.Not{
        expression: %Spek.AnyOf{
          children: [
            %Spek.Check{module: MyModule, fun: :check_a, args: []},
            %Spek.Check{module: MyModule, fun: :check_b, args: []}
          ],
        }
      }
  """
  @doc type: :builder
  @spec nor(expression, expression) :: expression
  def nor(a, b) do
    negate(any_of(a, b))
  end

  @doc """
  Builds an expression that is always true. 

  ## Example

      iex> pass()
      %Spek.Literal{result: true, satisfied?: true}
      
      iex> pass(:ok)
      %Spek.Literal{result: :ok, satisfied?: true}
      
      iex> pass({:ok, "value"})
      %Spek.Literal{result: {:ok, "value"}, satisfied?: true}
  """
  @doc type: :builder
  @spec pass(truthy) :: Literal.t()
  def pass(result \\ true) do
    %Literal{result: result, satisfied?: true}
  end

  @doc """
  Builds the exclusive or of the given expressions.

  ## Example

      iex> xor(check(MyModule, :check_a, []), check(MyModule, :check_b, []))
      %Spek.AnyOf{
        children: [
          %Spek.AllOf{
            children: [
              %Spek.Check{module: MyModule, fun: :check_a, args: []},
              %Spek.Not{
                expression: %Spek.Check{
                  module: MyModule,
                  fun: :check_b,
                  args: []
                }
              }
            ]
          },
          %Spek.AllOf{
            children: [
              %Spek.Not{
                expression: %Spek.Check{
                  module: MyModule,
                  fun: :check_a,
                  args: []
                }
              },
              %Spek.Check{module: MyModule, fun: :check_b, args: []}
            ]
          }
        ]
      }
  """
  @doc type: :builder
  @spec xor(expression, expression) :: expression
  def xor(a, b) do
    any_of([
      all_of(a, negate(b)),
      all_of(negate(a), b)
    ])
  end

  ## Evaluation

  @doc """
  Lazily evaluates the given expression and returns the result as a boolean.

  ## Examples

      iex> eval?(
      ...>   %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>   "hola, amiga"
      ...> )
      true
      
      iex> eval?(
      ...>   %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>   "hello, friend"
      ...> )
      false
  """
  @doc type: :evaluation
  @spec eval?(expression, context) :: boolean
  def eval?(expr, context \\ [])

  def eval?(%Literal{satisfied?: satisfied?}, _) do
    satisfied?
  end

  def eval?(
        %Check{module: module, fun: fun, args: args},
        context
      ) do
    module
    |> apply(fun, replace_args(args, context))
    |> Spek.to_boolean()
  end

  def eval?(%Not{expression: expression}, context) do
    not eval?(expression, context)
  end

  def eval?(%AllOf{children: children}, context) do
    Enum.all?(children, &eval?(&1, context))
  end

  def eval?(%AnyOf{children: children}, context) do
    Enum.any?(children, &eval?(&1, context))
  end

  @doc """
  Lazily evaluates the given expression and returns `:ok` or an error.

  ## Examples

      iex> eval(
      ...>   %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>   "hola, amiga"
      ...> )
      :ok
      
      iex> eval(
      ...>   %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>   "hello, friend"
      ...> )
      {:error, %Spek.EvaluationError{message: "rule evaluation failed"}}
  """
  @doc type: :evaluation
  @spec eval(expression, context) :: :ok | {:error, EvaluationError.t()}
  def eval(expression, context \\ []) do
    if eval?(expression, context) do
      :ok
    else
      {:error, EvaluationError.new()}
    end
  end

  @doc """
  Lazily evaluates the given expression and raises an exception if it is not
  satisfied.

  ## Examples

      iex> eval!(
      ...>   %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>   "hola, amiga"
      ...> )
      :ok
      
      iex> eval!(
      ...>   %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>   "hello, friend"
      ...> )
      ** (Spek.EvaluationError) rule evaluation failed
  """
  @doc type: :evaluation
  @spec eval!(expression, context) :: :ok | no_return()
  def eval!(expression, context \\ []) do
    if eval?(expression, context) do
      :ok
    else
      raise EvaluationError
    end
  end

  @doc """
  Lazily evaluates the given expression and returns the evaluated part of the
  expression.

  ## Examples

      iex> eval_tree(
      ...>   %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>   "hola, amiga"
      ...> )
      {
        :ok,
        %Spek.Check{
          module: String,
          fun: :starts_with?,
          args: [:ctx, "hola"],
          result: true,
          satisfied?: true
        }
      }
      
      iex> eval_tree(
      ...>   %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>   "hello, friend"
      ...> )
      {
        :error,
        %Spek.EvaluationError{
          expression: %Spek.Check{
            args: [:ctx, "hola"],
            fun: :starts_with?,
            module: String,
            result: false,
            satisfied?: false
          },
          message: "rule evaluation failed"
        }
      }
  """
  @doc type: :evaluation
  @spec eval_tree(expression, term) ::
          {:ok, expression} | {:error, EvaluationError.t()}
  def eval_tree(expression, context \\ []) do
    case do_eval_tree(expression, context) do
      %{satisfied?: true} = evaluated_expression ->
        {:ok, evaluated_expression}

      %{satisfied?: false} = evaluated_expression ->
        {:error, EvaluationError.with_expression(evaluated_expression)}
    end
  end

  @doc """
  Lazily evaluates the given expression and returns the evaluated part of the
  expression.

  Raises if the rule is not satisfied. Unlike `eval!/2`, the raised exception
  contains the evaluated expression.

  ## Examples

      iex> eval_tree!(
      ...>   %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>   "hola, amiga"
      ...> )
      %Spek.Check{
        module: String,
        fun: :starts_with?,
        args: [:ctx, "hola"],
        result: true,
        satisfied?: true
      }
      
      iex> eval_tree!(
      ...>   %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>   "hello, friend"
      ...> )
      ** (Spek.EvaluationError) rule evaluation failed
  """
  @doc type: :evaluation
  @spec eval_tree!(expression, term) :: expression | no_return
  def eval_tree!(expression, context \\ []) do
    case do_eval_tree(expression, context) do
      %{satisfied?: true} = evaluated_expression ->
        evaluated_expression

      %{satisfied?: false} = evaluated_expression ->
        raise EvaluationError.with_expression(evaluated_expression)
    end
  end

  defp do_eval_tree(%Literal{} = literal, _) do
    literal
  end

  defp do_eval_tree(
         %Check{module: module, fun: fun, args: args} = check,
         context
       ) do
    result = apply(module, fun, replace_args(args, context))
    %{check | result: result, satisfied?: Spek.to_boolean(result)}
  end

  defp do_eval_tree(
         %Not{expression: expression} = not_expr,
         context
       ) do
    evaluated_expression =
      do_eval_tree(expression, context)

    %{
      not_expr
      | expression: evaluated_expression,
        satisfied?: not evaluated_expression.satisfied?
    }
  end

  defp do_eval_tree(
         %AllOf{children: children} = and_,
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

  defp do_eval_tree(
         %AnyOf{children: children} = or_,
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
    case do_eval_tree(expression, context) do
      %{satisfied?: true} = expr -> {:cont, {true, [expr | acc]}}
      %{satisfied?: false} = expr -> {:halt, {false, [expr | acc]}}
    end
  end

  defp any_of_reducer(expression, {_, acc}, context) do
    case do_eval_tree(expression, context) do
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

  ## Filter/reject

  @doc """
  Filters the given enumerable to only retain the items that satisfy the given
  expression.

  ## Example

      iex> filter(
      ...>   ["hello, friend", "hola, amiga"],
      ...>   %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]}
      ...> )
      ["hola, amiga"]
  """
  @doc type: :evaluation
  @spec filter(Enumerable.t(), expression) :: Enumerable.t()
  def filter(items, expression) do
    Enum.filter(items, &eval?(expression, &1))
  end

  @doc """
  Filters the given enumerable to only retain the items that _do not_ satisfy
  the given expression.

  ## Example

      iex> reject(
      ...>   ["hello, friend", "hola, amiga"],
      ...>   %Check{module: String, fun: :starts_with?, args: [:ctx, "hello"]}
      ...> )
      ["hola, amiga"]
  """
  @doc type: :evaluation
  @spec reject(Enumerable.t(), expression) :: Enumerable.t()
  def reject(items, expression) do
    Enum.reject(items, &eval?(expression, &1))
  end

  @doc false
  def to_boolean(bool) when is_boolean(bool), do: bool
  def to_boolean(:ok), do: true
  def to_boolean({:ok, _}), do: true
  def to_boolean(:error), do: false
  def to_boolean({:error, _}), do: false
end
