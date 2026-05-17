defmodule Spek.Literal do
  @moduledoc """
  Struct that represents an authorization rule that evaluates to a fixed value.
  """

  @type t ::
          %__MODULE__{satisfied?: true, result: Spek.truthy()}
          | %__MODULE__{satisfied?: false, result: Spek.falsy()}

  @enforce_keys [:satisfied?, :result]

  defstruct [:satisfied?, :result]
end
