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
      @spec unquote(function_name)() :: Spec.Check.t()
      def unquote(function_name)() do
        %Spek.Check{
          module: unquote(module),
          fun: unquote(fun),
          args: unquote(args)
        }
      end
    end
  end

  @doc """
  Generates three functions from a single check definition.

  ## Generated functions

  The arity of the generated function depends on the number of arguments set
  with the second macro argument.

  - `{name}?` - A predicate function that returns the result of the boolean
    expression defined in the do-block.
  - `{name}` - A function that runs the boolean expression defined in the
    do-block and returns `:ok` or `{:error, term}`.
  - `{name}_check` - A function that returns a `Spek.Check` struct.

  ## Arguments

  - `name` - The base name for three functions.
  - `args` - The argument or list of arguments passed to each function. These
    argument names can be used in the do-block.
  - `opts` - Additional options:
    - `:args` - The list of arguments as used in the `Spek.Check` struct.
    - `:reason` - The reason used in the error tuple. Defaults to `:failed`.

  ## Do-block

  The do-block is required to be a boolean expression

  ## Example

  This macro call:

      defmodule MyApp.MyModule do
        import Spek.Macros
        
        defcheck :account_balanced, account,
          args: [:ctx],
          reason: :account_unbalanced do
          account.balance >= 0
        end
      end

  Will result in these three functions:

      def account_balanced?(account) do
        account.balance >= 0
      end

      def account_balanced(account) do
        if account_balanced(account),
          do: :ok,
          else: {:error, :account_unbalanced}
      end

      def account_balanced_check do
        %Check{module: MyApp.MyModule, fun: :account_balanced, args: [:ctx]}
      end

  The generated functions can have an arbitrary number of arguments. For
  example, this macro call defines two arguments, `user` and `organization`:

      defcheck :matching_organization, [user, organization],
        args: [{:ctx, :user}, {:ctx, :organization}],
        reason: :no_organization_match do
        user.organization_id == organization.id
      end

  Which is expanded to:
      
      def matching_organization?(user, account) do
        user.organization_id == organization.id
      end

      def matching_organization(user, account) do
        if matching_organization?(user, account),
          do: :ok,
          else: {:error, :no_organization_match}
      end

      def matching_organization_check do
        %Check{
          module: MyApp.MyModule,
          fun: :matching_organization,
          args: [{:ctx, :user}, {:ctx, :organization}]
        }
      end
  """
  defmacro defcheck(name, args, opts, do: body) do
    args = List.wrap(args)
    reason = Keyword.get(opts, :reason, :failed)
    check_args = Keyword.fetch!(opts, :args)
    module = __CALLER__.module
    check_fun_name = :"#{name}_check"
    predicate_fun_name = :"#{name}?"

    quote do
      @spec unquote(check_fun_name)() :: Spec.Check.t()
      def unquote(check_fun_name)() do
        %Spek.Check{
          module: unquote(module),
          fun: unquote(name),
          args: unquote(check_args)
        }
      end

      def unquote(predicate_fun_name)(unquote_splicing(args)) do
        unquote(body)
      end

      def unquote(name)(unquote_splicing(args)) do
        if unquote(predicate_fun_name)(unquote_splicing(args)),
          do: :ok,
          else: {:error, unquote(reason)}
      end
    end
  end
end
