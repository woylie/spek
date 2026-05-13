defmodule Spek.EvaluationError do
  @moduledoc """
  Error representing a failed rule evaluation.
  """

  @default_message "rule evaluation failed"

  @typedoc """
  Struct returned or raised if an authorization check fails.

  `expression` contains the parts of the policy expression that were performed
  and their results. Depending on the evaluation function used, this may be the
  complete expression, or only the parts of it that were evaluated until a
  decision was made.
  """
  @type t :: %__MODULE__{
          message: String.t(),
          expression: Spek.expression() | nil
        }

  defexception [:message, :expression]

  def message(exception) do
    exception.message || @default_message
  end

  @spec new(String.t()) :: __MODULE__.t()
  def new(message \\ @default_message) do
    %__MODULE__{message: message}
  end

  @doc false
  def with_expression(expression) do
    %__MODULE__{
      message: @default_message,
      expression: expression
    }
  end
end
