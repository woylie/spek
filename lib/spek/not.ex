defmodule Spek.Not do
  @moduledoc """
  Struct that represents a boolean negation.
  """

  @type t :: %__MODULE__{
          expression: Spek.expression(),
          satisfied?: boolean | nil
        }

  defstruct [:expression, :satisfied?]
end
