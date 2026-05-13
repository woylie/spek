defmodule Spek.And do
  @moduledoc """
  Struct that represents a combination of expressions that all must be true.

  An `And` without children evaluates to `true`.
  """

  @type t :: %__MODULE__{
          children: [Spek.expression()],
          satisfied?: boolean | nil
        }

  defstruct [:satisfied?, children: []]
end
