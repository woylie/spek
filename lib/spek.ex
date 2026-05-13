defmodule Spek do
  @moduledoc """
  Documentation for `Spek`.
  """

  alias Spek.And
  alias Spek.Check
  alias Spek.Literal
  alias Spek.Not
  alias Spek.Or

  @type expression :: And.t() | Or.t() | Check.t() | Literal.t() | Not.t()

  @type truthy :: true | :ok | {:ok, term}
  @type falsy :: false | :error | {:error, term}
  @type result :: truthy | falsy

  ## Builders

  @doc """
  Builds an expression that requires all children to be true.

  ## Example

      iex> all([check(MyModule, :check_a, []), check(MyModule, :check_b, [])])
      %Spek.And{
        children: [
          %Spek.Check{module: MyModule, fun: :check_a, args: []},
          %Spek.Check{module: MyModule, fun: :check_b, args: []}
        ]
      }
  """
  @doc type: :builder
  @spec all([expression]) :: And.t()
  def all(children) when is_list(children) do
    %And{children: children}
  end

  @doc """
  Builds an expression that requires both children to be true.

  ## Example

      iex> all(check(MyModule, :check_a, []), check(MyModule, :check_b, []))
      %Spek.And{
        children: [
          %Spek.Check{module: MyModule, fun: :check_a, args: []},
          %Spek.Check{module: MyModule, fun: :check_b, args: []}
        ]
      }
  """
  @doc type: :builder
  @spec all(expression, expression) :: And.t()
  def all(a, b) do
    %And{children: [a, b]}
  end

  @doc """
  Builds an expression that requires at least one child to be true.

  ## Example

      iex> any([check(MyModule, :check_a, []), check(MyModule, :check_b, [])])
      %Spek.Or{
        children: [
          %Spek.Check{module: MyModule, fun: :check_a, args: []},
          %Spek.Check{module: MyModule, fun: :check_b, args: []}
        ]
      }
  """
  @doc type: :builder
  @spec any([expression]) :: Or.t()
  def any(children) when is_list(children) do
    %Or{children: children}
  end

  @doc """
  Builds an expression that requires at least one child to be true.

  ## Example

      iex> any(check(MyModule, :check_a, []), check(MyModule, :check_b, []))
      %Spek.Or{
        children: [
          %Spek.Check{module: MyModule, fun: :check_a, args: []},
          %Spek.Check{module: MyModule, fun: :check_b, args: []}
        ]
      }
  """
  @doc type: :builder
  @spec any(expression, expression) :: Or.t()
  def any(a, b) do
    %Or{children: [a, b]}
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
      %Spek.Literal{value: false, satisfied?: false}
      
      iex> fail(:error)
      %Spek.Literal{value: :error, satisfied?: false}
      
      iex> fail({:error, :some_reason})
      %Spek.Literal{value: {:error, :some_reason}, satisfied?: false}
  """
  @doc type: :builder
  @spec fail(falsy) :: Literal.t()
  def fail(value \\ false) do
    %Literal{value: value, satisfied?: false}
  end

  @doc """
  Builds an expression that always evaluates to the same value.

  ## Examples

      iex> literal(true)
      %Spek.Literal{value: true, satisfied?: true}
      
      iex> literal(:ok)
      %Spek.Literal{value: :ok, satisfied?: true}

      iex> literal({:ok, "value"})
      %Spek.Literal{value: {:ok, "value"}, satisfied?: true}

      iex> literal(false)
      %Spek.Literal{value: false, satisfied?: false}
      
      iex> literal(:error)
      %Spek.Literal{value: :error, satisfied?: false}
      
      iex> literal({:error, :some_reason})
      %Spek.Literal{value: {:error, :some_reason}, satisfied?: false}
  """
  @doc type: :builder
  @spec literal(result) :: Literal.t()
  def literal(value) do
    %Literal{value: value, satisfied?: to_boolean(value)}
  end

  @doc """
  Builds an expression that evaluates to true unless both children are true.

  ## Example

      iex> nand(check(MyModule, :check_a, []), check(MyModule, :check_b, []))
      %Spek.Not{
        expression: %Spek.And{
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
    negate(all(a, b))
  end

  @doc """
  Negates the given expression.

  ## Examples

      iex> negate(literal(true))
      %Spek.Not{expression: %Spek.Literal{value: true, satisfied?: true}}

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
        expression: %Spek.Or{
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
    negate(any(children))
  end

  @doc """
  Builds an expression that evaluates to true if both children are false.

  ## Example

      iex> nor(check(MyModule, :check_a, []), check(MyModule, :check_b, []))
      %Spek.Not{
        expression: %Spek.Or{
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
    negate(any(a, b))
  end

  @doc """
  Builds an expression that is always true. 

  ## Example

      iex> pass()
      %Spek.Literal{value: true, satisfied?: true}
      
      iex> pass(:ok)
      %Spek.Literal{value: :ok, satisfied?: true}
      
      iex> pass({:ok, "value"})
      %Spek.Literal{value: {:ok, "value"}, satisfied?: true}
  """
  @doc type: :builder
  @spec pass(truthy) :: Literal.t()
  def pass(value \\ true) do
    %Literal{value: value, satisfied?: true}
  end

  @doc """
  Builds the exclusive or of the given expressions.

  ## Example

      iex> xor(check(MyModule, :check_a, []), check(MyModule, :check_b, []))
      %Spek.Or{
        children: [
          %Spek.And{
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
          %Spek.And{
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
    any([
      all(a, negate(b)),
      all(negate(a), b)
    ])
  end

  defp to_boolean(bool) when is_boolean(bool), do: bool
  defp to_boolean(:ok), do: true
  defp to_boolean({:ok, _}), do: true
  defp to_boolean(:error), do: false
  defp to_boolean({:error, _}), do: false
end
