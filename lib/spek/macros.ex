defmodule Spek.Macros do
  @moduledoc """
  Convenience macros for defining check functions.

  The usage of these macros is optional, but they can make your rules more
  readable.
  """

  @doc """
  Defines a function that returns a `Spek.Check` struct that uses an existing
  function in the same module.

  ## Example

  Let's say you have an existing `active_user/1` function that you want to use
  in a Spek expression. Instead of defining the `Check` struct manually, you can
  use `build_check` and pass the function name and the arguments.

      defmodule MyApp.MyModule do
        def active_user(%{state: :active}), do: :ok
        def active_user(%{state: :inactive}), do: {:error, :user_inactive}

        build_check(:active_user, [:ctx])
      end

  This will compile a `{fun}_check/0` function like this:

      def active_user_check do
        %Check{module: MyApp.MyModule, fun: :active_user, args: [:ctx]}
      end

  You can then use this function when building complex rules:

      Spek.all([
        MyApp.MyModule.active_user_check(),
        # ...
      ])
  """
  defmacro build_check(fun, args) do
    module = __CALLER__.module
    function_name = :"#{fun}_check"

    quote do
      def unquote(function_name)() do
        %Spek.Check{
          module: unquote(module),
          fun: unquote(fun),
          args: unquote(args)
        }
      end
    end
  end
end
