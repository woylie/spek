defmodule Spek.Checks do
  @moduledoc false

  def always_true, do: true
  def always_false, do: false

  def from_bool(true), do: :ok
  def from_bool(false), do: :error

  def from_result_key(%{result: result}), do: result

  def return_arg(arg), do: arg
end
