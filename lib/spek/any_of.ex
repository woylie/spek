defmodule Spek.AnyOf do
  @moduledoc """
  Struct that represents a combination of expressions of which at least one must
  be true.

  Without children, the expression evaluates to `false`.
  """

  @type t :: %__MODULE__{
          children: [Spek.expression()],
          satisfied?: boolean | nil
        }

  defstruct [:satisfied?, children: []]
end
