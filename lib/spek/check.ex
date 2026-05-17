defmodule Spek.Check do
  @moduledoc """
  Struct that represents the evaluation result of a single check function.
  """

  @typedoc """
  Representation of a single policy check.

  - `module`, `fun`, `args` - Module, function, and arguments for the check
    function to run. To reference a key in the context argument passed to the
    `eval` functions, use `{:ctx, atom}`. To pass the whole context as an
    argument, use `:ctx`.
  - `result` - The original return value of the check function.
  - `satisfied?` - A boolean set depending on the return value of the check
    function.

  `result` and `satisfied?` are only set when the policy is evaluated.

  The `result` values `true`, `:ok`, and `{:ok, term}` are mapped to
  `satisfied?: true`. The result values `false`, `:error`, and `{:error, term}`
  are mapped to `satisfied?: false`.
  """
  @type t :: %__MODULE__{
          module: module,
          fun: fun,
          args: args(),
          result: Spek.result() | nil,
          satisfied?: boolean | nil
        }

  @type args :: [{:ctx, atom} | :ctx | term]

  @enforce_keys [:module, :fun, :args]

  defstruct [:module, :fun, :args, :result, :satisfied?]
end
