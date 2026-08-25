defmodule Spek.ResultChecks do
  @moduledoc false

  import Spek.Macros

  defcheck literal_true(a) do
    true
  end

  defcheck literal_false(a) do
    false
  end

  defcheck literal_ok(a) do
    :ok
  end

  defcheck literal_error(a) do
    :error
  end

  defcheck literal_ok_tuple(a) do
    {:ok, :v}
  end

  defcheck literal_error_tuple(a) do
    {:error, :v}
  end

  defcheck computed_ok_tuple(a) do
    {:ok, a}
  end

  defcheck computed_error_tuple(a) do
    {:error, a}
  end
end
