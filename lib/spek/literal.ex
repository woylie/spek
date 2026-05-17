defmodule Spek.Literal do
  @moduledoc """
  Struct that represents an authorization rule that evaluates to a fixed value.
  """

  @type t :: %__MODULE__{satisfied?: boolean, result: Spek.result()}

  @enforce_keys [:satisfied?, :result]

  defstruct [:satisfied?, :result]
end
