defmodule Spek.Or do
  @moduledoc """
  Struct that represents a combination of checks one of which must be true.

  An `Or` without children evaluates to `false`.
  """

  @type t :: %__MODULE__{
          children: [Spek.expression()],
          satisfied?: boolean | nil
        }

  defstruct [:satisfied?, children: []]
end
