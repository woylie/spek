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
  Evaluates the given expression and returns the result as a boolean.

  Stops early as soon as the final outcome is determined.

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
  Evaluates the given expression and returns `:ok` or an error tuple.

  Stops early as soon as the final outcome is determined.

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
  Evaluates the given expression and raises an exception if it is not satisfied.

  Stops early as soon as the final outcome is determined.

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
  Evaluates the given expression and returns the expression annotated with
  evaluation results.

  Stops early as soon as the final outcome is determined. The returned
  expression only contains the evaluated parts.

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
    case do_eval_tree(expression, context, :halt) do
      %{satisfied?: true} = evaluated_expression ->
        {:ok, evaluated_expression}

      %{satisfied?: false} = evaluated_expression ->
        {:error, EvaluationError.with_expression(evaluated_expression)}
    end
  end

  @doc """
  Evaluates the given expression and returns the expression annotated with
  evaluation results.

  Stops early as soon as the final outcome is determined. The returned
  expression only contains the evaluated parts.

  Raises an exception if the rule is not satisfied. Unlike `eval!/2`, the
  exception contains the evaluated expression.

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
    case do_eval_tree(expression, context, :halt) do
      %{satisfied?: true} = evaluated_expression ->
        evaluated_expression

      %{satisfied?: false} = evaluated_expression ->
        raise EvaluationError.with_expression(evaluated_expression)
    end
  end

  @doc """
  Evaluates the given expression and returns the expression annotated with the
  expression result.

  Always evaluates the entire expression, even if the final outcome could be
  determined earlier.

  ## Examples

      iex> eval_tree_all(
      ...>   all_of([
      ...>     %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>     %Check{module: String, fun: :ends_with?, args: [:ctx, "amiga"]}
      ...>   ]),
      ...>   "hola, amiga"
      ...> )
      {
        :ok,
        %Spek.AllOf{
          children: [
            %Spek.Check{
              module: String,
              fun: :starts_with?,
              args: [:ctx, "hola"],
              result: true,
              satisfied?: true
            },
            %Spek.Check{
              module: String,
              fun: :ends_with?,
              args: [:ctx, "amiga"],
              result: true,
              satisfied?: true
            }
          ],
          satisfied?: true
        }
      }

      iex> eval_tree_all(
      ...>   all_of([
      ...>     %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>     %Check{module: String, fun: :ends_with?, args: [:ctx, "amiga"]}
      ...>   ]),
      ...>   "hola, amigo"
      ...> )
      {
        :error,
        %Spek.EvaluationError{
          expression: %Spek.AllOf{
            children: [
              %Spek.Check{
                module: String,
                fun: :starts_with?,
                args: [:ctx, "hola"],
                result: true,
                satisfied?: true
              },
              %Spek.Check{
                module: String,
                fun: :ends_with?,
                args: [:ctx, "amiga"],
                result: false,
                satisfied?: false
              }
            ],
            satisfied?: false
          },
          message: "rule evaluation failed"
        }
      }
  """
  @doc type: :evaluation
  @spec eval_tree_all(expression, term) ::
          {:ok, expression} | {:error, EvaluationError.t()}
  def eval_tree_all(expression, context \\ []) do
    case do_eval_tree(expression, context, :cont) do
      %{satisfied?: true} = evaluated_expression ->
        {:ok, evaluated_expression}

      %{satisfied?: false} = evaluated_expression ->
        {:error, EvaluationError.with_expression(evaluated_expression)}
    end
  end

  @doc """
  Evaluates the given expression and returns the expression annotated with
  evaluation results.

  Raises if the expression is not satisfied. Unlike `eval!/2`, the raised
  exception contains the evaluated expression.

  Always evaluates the entire expression, even if the final outcome could be
  determined earlier.

  ## Examples

      iex> eval_tree_all!(
      ...>   any_of([
      ...>     %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>     %Check{module: String, fun: :ends_with?, args: [:ctx, "amiga"]}
      ...>   ]),
      ...>   "hola, amiga"
      ...> )
      %Spek.AnyOf{
        satisfied?: true,
        children: [
          %Spek.Check{
            module: String,
            fun: :starts_with?,
            args: [:ctx, "hola"],
            result: true,
            satisfied?: true
          },
          %Spek.Check{
            module: String,
            fun: :ends_with?,
            args: [:ctx, "amiga"],
            result: true,
            satisfied?: true
          }
        ]
      }

      iex> eval_tree_all!(
      ...>   %Check{module: String, fun: :starts_with?, args: [:ctx, "hola"]},
      ...>   "hello, friend"
      ...> )
      ** (Spek.EvaluationError) rule evaluation failed
  """
  @doc type: :evaluation
  @spec eval_tree_all!(expression, term) :: expression | no_return
  def eval_tree_all!(expression, context \\ []) do
    case do_eval_tree(expression, context, :cont) do
      %{satisfied?: true} = evaluated_expression ->
        evaluated_expression

      %{satisfied?: false} = evaluated_expression ->
        raise EvaluationError.with_expression(evaluated_expression)
    end
  end

  defp do_eval_tree(%Literal{} = literal, _, _) do
    literal
  end

  defp do_eval_tree(
         %Check{module: module, fun: fun, args: args} = check,
         context,
         _
       ) do
    result = apply(module, fun, replace_args(args, context))
    %{check | result: result, satisfied?: Spek.to_boolean(result)}
  end

  defp do_eval_tree(
         %Not{expression: expression} = not_expr,
         context,
         mode
       ) do
    evaluated_expression =
      do_eval_tree(expression, context, mode)

    %{
      not_expr
      | expression: evaluated_expression,
        satisfied?: not evaluated_expression.satisfied?
    }
  end

  defp do_eval_tree(
         %AllOf{children: children} = and_,
         context,
         mode
       ) do
    {satisfied?, evaluated_children} =
      Enum.reduce_while(
        children,
        {true, []},
        &all_of_reducer(&1, &2, context, mode)
      )

    %{and_ | satisfied?: satisfied?, children: Enum.reverse(evaluated_children)}
  end

  defp do_eval_tree(
         %AnyOf{children: children} = or_,
         context,
         mode
       ) do
    {satisfied?, evaluated_children} =
      Enum.reduce_while(
        children,
        {false, []},
        &any_of_reducer(&1, &2, context, mode)
      )

    %{or_ | satisfied?: satisfied?, children: Enum.reverse(evaluated_children)}
  end

  defp all_of_reducer(expression, {previous_result, acc}, context, mode) do
    case do_eval_tree(expression, context, mode) do
      %{satisfied?: true} = expr ->
        {:cont, {previous_result, [expr | acc]}}

      %{satisfied?: false} = expr ->
        {mode, {false, [expr | acc]}}
    end
  end

  defp any_of_reducer(expression, {previous_result, acc}, context, mode) do
    case do_eval_tree(expression, context, mode) do
      %{satisfied?: true} = expr ->
        {mode, {true, [expr | acc]}}

      %{satisfied?: false} = expr ->
        {:cont, {false or previous_result, [expr | acc]}}
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

  ## Optimization

  @doc """
  Performs optimizations on the given expression.

  ## Examples

      iex> Spek.optimize(%AnyOf{
      ...>   children: [
      ...>     %AllOf{
      ...>       children: [
      ...>         %Check{fun: :check1},
      ...>         %Check{fun: :check2}
      ...>       ]
      ...>     },
      ...>     %AllOf{
      ...>       children: [
      ...>         %Check{fun: :check3},
      ...>         %Check{fun: :check1}
      ...>       ]
      ...>     },
      ...>     %Check{fun: :check4}
      ...>   ]
      ...> })
      %AnyOf{
        children: [
          %AllOf{
            children: [
              %Check{fun: :check1},
              %AnyOf{
                children: [
                  %Check{fun: :check2},
                  %Check{fun: :check3}
                ]
              }
            ]
          },
          %Check{fun: :check4}
        ]
      }

  ## Optimizations

  | Optimization | Formula |
  |---|---|
  | Identity (AND) | `A and true = A` |
  | Identity (OR) | `A or false = A` |
  | Annihilation (AND) | `A and false = false` |
  | Annihilation (OR) | `A or true = true` |
  | Double negation elimination | `not (not A) = A` |
  | Negation of literals | `not true = false`, `not false = true` |
  | De Morgan’s law (AND) | `not (A and B) = (not A) or (not B)` |
  | De Morgan’s law (OR) | `not (A or B) = (not A) and (not B)` |
  | Empty conjunction | `allof() = true` |
  | Empty disjunction | `anyof() = false` |
  | Single-child conjunction elimination | `allof(A) = A` |
  | Single-child disjunction elimination | `anyof(A) = A` |
  | Deduplication (AND) | `A and A = A` |
  | Deduplication (OR) | `A or A = A` |
  | Factoring OR over AND | `(A and B) or (A and C) = A and (B or C)` |
  | Factoring AND over OR | `(A or B) and (A or C) = A or (B and C)` |
  """
  @doc type: :optimization
  @spec optimize(expression) :: expression
  def optimize(%Literal{} = literal) do
    literal
  end

  def optimize(%Check{} = check) do
    check
  end

  def optimize(%Not{expression: expression}) do
    case optimize(expression) do
      # not(not(expr)) == expr
      %Not{expression: expr} ->
        expr

      # not(true) == false, not(false) == true
      %Literal{satisfied?: bool} ->
        %Literal{satisfied?: not bool}

      # not (A and B) = (not A) or (not B)
      %AllOf{children: children} ->
        %AnyOf{children: Enum.map(children, &optimize(%Not{expression: &1}))}

      # not (A or B) = (not A) and (not B)
      %AnyOf{children: children} ->
        %AllOf{children: Enum.map(children, &optimize(%Not{expression: &1}))}

      # otherwise, not(expr)
      expr ->
        %Not{expression: expr}
    end
  end

  def optimize(%AllOf{children: []}) do
    %Literal{satisfied?: true}
  end

  def optimize(%AllOf{children: [child]}) do
    optimize(child)
  end

  def optimize(%AllOf{children: [_ | _]} = all_of) do
    case factorize(all_of) do
      %AllOf{} = all_of ->
        do_optimize_all_of(all_of)

      %AnyOf{} = any_of ->
        optimize(any_of)
    end
  end

  def optimize(%AnyOf{children: []}) do
    %Literal{satisfied?: false}
  end

  def optimize(%AnyOf{children: [child]}) do
    optimize(child)
  end

  def optimize(%AnyOf{children: [_ | _]} = any_of) do
    case factorize(any_of) do
      %AnyOf{} = any_of ->
        do_optimize_any_of(any_of)

      %AllOf{} = all_of ->
        optimize(all_of)
    end
  end

  defp do_optimize_all_of(%AllOf{children: [_ | _] = children}) do
    {children, _} =
      Enum.reduce_while(children, {[], MapSet.new()}, fn child, {acc, seen} ->
        child = optimize(child)

        cond do
          # allof(A, false) = false
          literal_false?(child) -> {:halt, {false, nil}}
          # allof(A, B, true) = allof(A, B)
          literal_true?(child) -> {:cont, {acc, seen}}
          # allof(A, B, A) = allof(A, B) => skip duplicates
          MapSet.member?(seen, child) -> {:cont, {acc, seen}}
          # otherwise, add child to accumulator
          true -> {:cont, {[child | acc], MapSet.put(seen, child)}}
        end
      end)

    case children do
      # wrap false from first condition in reducer
      false -> %Literal{satisfied?: false}
      # allof(A) = A
      [child] -> child
      # allof() = true
      [] -> %Literal{satisfied?: true}
      # return new allof
      children -> %AllOf{children: Enum.reverse(children)}
    end
  end

  defp do_optimize_any_of(%AnyOf{children: children}) do
    {children, _} =
      Enum.reduce_while(
        children,
        {[], MapSet.new()},
        fn child, {acc, seen} ->
          child = optimize(child)

          cond do
            # anyof(A, true) = true
            literal_true?(child) -> {:halt, {true, nil}}
            # anyof(A, B, false) = anyof(A, B)
            literal_false?(child) -> {:cont, {acc, seen}}
            # anyOf(A, B, A) = anyof(A, B) => skip duplicates
            MapSet.member?(seen, child) -> {:cont, {acc, seen}}
            # otherwise, add child to accumulator
            true -> {:cont, {[child | acc], MapSet.put(seen, child)}}
          end
        end
      )

    case children do
      # wrap true from first condition in reducer
      true -> %Literal{satisfied?: true}
      # anyof(A) = A
      [child] -> child
      # anyof() = false
      [] -> %Literal{satisfied?: false}
      # return new anyof
      children -> %AnyOf{children: Enum.reverse(children)}
    end
  end

  defp literal_true?(%Literal{satisfied?: true}), do: true
  defp literal_true?(_), do: false

  defp literal_false?(%Literal{satisfied?: false}), do: true
  defp literal_false?(_), do: false

  defp factorize(%AllOf{children: children} = all_of) do
    # find all AnyOf children; only factorize if there is more than one
    {any_ofs, other} = Enum.split_with(children, &match?(%AnyOf{}, &1))

    case any_ofs do
      [] ->
        all_of

      [_] ->
        all_of

      _ ->
        # find all children that are common among the AnyOfs
        common_expressions = find_common_expressions(any_ofs)

        if MapSet.size(common_expressions) == 0 do
          all_of
        else
          # if there are common children, we can factorize
          do_factorize_any_ofs(any_ofs, other, common_expressions)
        end
    end
  end

  defp factorize(%AnyOf{children: children} = any_of) do
    # find all AllOf children; only factorize if there is more than one
    {all_ofs, other} = Enum.split_with(children, &match?(%AllOf{}, &1))

    case all_ofs do
      [] ->
        any_of

      [_] ->
        any_of

      _ ->
        # find all children that are common among the AllOfs
        common_expressions = find_common_expressions(all_ofs)

        if MapSet.size(common_expressions) == 0 do
          any_of
        else
          # if there are common children, we can factorize
          do_factorize_all_ofs(all_ofs, other, common_expressions)
        end
    end
  end

  defp find_common_expressions(ofs) do
    ofs
    |> Enum.map(fn
      %AllOf{children: children} -> MapSet.new(children)
      %AnyOf{children: children} -> MapSet.new(children)
    end)
    |> Enum.reduce(&MapSet.intersection/2)
  end

  defp do_factorize_all_ofs(all_ofs, other, common_expressions) do
    common_expressions = MapSet.to_list(common_expressions)

    # remove the common child expressions from all AllOfs
    factored_branches =
      Enum.map(all_ofs, fn %AllOf{children: children} ->
        case children -- common_expressions do
          # allof() = true
          [] -> %Literal{satisfied?: true}
          # allof(A) = A
          [child] -> child
          # if there is more than one child, build a new AllOf
          children -> %AllOf{children: children}
        end
      end)

    # (A and B) or (A and C) = A and (B or C)
    new_all_of = %AllOf{
      children: common_expressions ++ [%AnyOf{children: factored_branches}]
    }

    case other do
      # if there were no none-AllOf expressions in the original AnyOf, just
      # return the factorized AllOf expression
      [] -> new_all_of
      # if there were none-Allof expressions in the original AnyOf, wrap the
      # factorized AllOf expression and the remaining expressions in an AnyOf
      # (A and B) or (A and C) or D = (A and (B or C)) or D
      _ -> %AnyOf{children: [new_all_of | other]}
    end
  end

  defp do_factorize_any_ofs(any_ofs, other, common_expressions) do
    common_expressions = MapSet.to_list(common_expressions)

    # remove the common child expressions from all AnyOfs
    factored_branches =
      Enum.map(any_ofs, fn %AnyOf{children: children} ->
        case children -- common_expressions do
          # anyof() = false
          [] -> %Literal{satisfied?: false}
          # anyof(A) = A
          [child] -> child
          # if there is more than one child, build a new AnyOf
          children -> %AnyOf{children: children}
        end
      end)

    # (A or B) and (A or C) = A or (B and C)
    new_any_of = %AnyOf{
      children: common_expressions ++ [%AllOf{children: factored_branches}]
    }

    case other do
      # if there were no none-AnyOf expressions in the original AllOf, just
      # return the factorized AnyOf expression
      [] -> new_any_of
      # if there were none-AnyOf expressions in the original AllOf, wrap the
      # factorized AnyOf expression and the remaining expressions in an AllOf
      # (A or B) and (A or C) and D = (A or (B and C)) and D
      _ -> %AllOf{children: [new_any_of | other]}
    end
  end

  @doc false
  def to_boolean(bool) when is_boolean(bool), do: bool
  def to_boolean(:ok), do: true
  def to_boolean({:ok, _}), do: true
  def to_boolean(:error), do: false
  def to_boolean({:error, _}), do: false
end
