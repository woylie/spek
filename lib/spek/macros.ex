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

        build_check(:active_user)
      end

  This will compile a `{fun}_check/0` function like this:

      def active_user_check(args \\\\ [:ctx]) do
        %Check{module: MyApp.MyModule, fun: :active_user, args: args}
      end

  You can then use this function when building complex rules:

      Spek.all_of[
        MyApp.MyModule.active_user_check(),
        # ...
      ])

  The second argument sets the default `args`. This:

      build_check(:active_user, [{:ctx, :user}])

  Compiles to:
    
      def active_user_check(args \\\\ [{:ctx, :user}]) do
        %Check{module: MyApp.MyModule, fun: :active_user, args: args}
      end
  """
  defmacro build_check(fun, args \\ [:ctx]) do
    module = __CALLER__.module
    function_name = :"#{fun}_check"

    quote do
      @spec unquote(function_name)() :: Spek.Check.t()
      def unquote(function_name)(args \\ unquote(args)) do
        %Spek.Check{
          module: unquote(module),
          fun: unquote(fun),
          args: args
        }
      end
    end
  end

  @doc """
  Generates three functions from a single check definition.

  ## Generated functions

  The arity of the generated function depends on the number of arguments passed
  to the macro.

  - `{name}?` - A predicate function that returns the result of the boolean
    expression defined in the do-block.
  - `{name}` - A function that runs the expression defined in the
    do-block and returns `:ok`, `:error`, `{:ok, term}`, or `{:error, term}`.
  - `{name}_check` - A function that returns a `Spek.Check` struct.

  ## Options

  - `:args` - The list of arguments as used in the `Spek.Check` struct.
    Defaults to `[:ctx]`.
  - `:reason` - The reason used in the error tuple. Defaults to `:failed`. This
    value is only used if the do-block returns a boolean.

  ## Do-block

  The do-block is required to return a boolean, `:ok`, `:error`, `{:ok, term}`,
  or `{:error, term}`.

  ## Example

  ### With boolean expression

  This macro call:

      defmodule MyApp.MyModule do
        import Spek.Macros
        
        defcheck account_balanced(account,
                   args: [:ctx],
                   reason: :account_unbalanced
                 ) do
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

      def account_balanced_check(args \\\\ [:ctx]) do
        %Check{module: MyApp.MyModule, fun: :account_balanced, args: args}
      end

  Alternatively, you can return :ok/:error values in the do-block with the same
  result:

      defmodule MyApp.MyModule do
        import Spek.Macros
        
        defcheck account_balanced(account, args: [:ctx]) do
          if account.balance >= 0, do: :ok, else: {:error, :account_unbalanced}
        end
      end

  The `account_balanced?/1` and `account_balanced/1` functions can be used
  directly, and the `account_balanced_check/0` function can be used
  with the Spek evaluation functions, or be combined with additional checks to
  define complex rules.

      def transfer_rule do
        Spek.all_of([
          account_balanced_check(),
          # additional checks
        ])
      end

      Spek.eval(transfer_rule(), %Account{balance: 100})

  You can also override the check arguments, e.g. if you combine multiple checks
  that work on different data:

      def transfer_rule do
        Spek.all_of([
          account_balanced_check([{:ctx, :account}]),
          # additional checks
        ])
      end

      Spek.eval(transfer_rule(), account: %Account{balance: 100})

  The generated functions can have an arbitrary number of arguments. For
  example, this macro call defines two arguments, `user` and `organization`:

      defcheck matching_organization(user, organization,
                 args: [{:ctx, :user}, {:ctx, :organization}],
                 reason: :no_organization_match
               ) do
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

      def matching_organization_check(args \\\\ [{:ctx, :user}, {:ctx, :organization}]) do
        %Check{
          module: MyApp.MyModule,
          fun: :matching_organization,
          args: args
        }
      end

  In this case, we would call the Spek evaluation functions like this:

      Spek.eval(matching_organization_check(),
        user: %User{organization_id: 1},
        organization: %Organization{id: 1}
      )
  """
  # credo:disable-for-next-line
  defmacro defcheck({name, _, raw_args}, do: body) do
    raw_args = raw_args || []

    {call_args, opts} =
      case raw_args do
        [call_args] ->
          {call_args, []}

        raw_args when is_list(raw_args) ->
          Enum.split(raw_args, length(raw_args) - 1)
      end

    call_args = List.wrap(call_args)
    opts = List.first(opts) || []

    reason = Keyword.get(opts, :reason, :failed)
    check_args = Keyword.get(opts, :args, [:ctx])
    module = __CALLER__.module
    check_fun_name = :"#{name}_check"
    predicate_fun_name = :"#{name}?"

    arg_types =
      for _ <- call_args do
        quote(do: term())
      end

    always_true? =
      case body do
        true -> true
        :ok -> true
        {:ok, _} -> true
        _ -> false
      end

    always_false? =
      case body do
        false -> true
        :error -> true
        {:error, _} -> true
        _ -> false
      end

    cond do
      always_true? ->
        ok_value = if is_boolean(body), do: :ok, else: body

        quote do
          @spec unquote(check_fun_name)(Spek.context()) :: Spek.Literal.t()
          def unquote(check_fun_name)(args \\ unquote(check_args)) do
            %Spek.Literal{result: unquote(body), satisfied?: true}
          end

          @spec unquote(predicate_fun_name)(unquote_splicing(arg_types)) :: true
          def unquote(predicate_fun_name)(unquote_splicing(call_args)) do
            true
          end

          @spec unquote(name)(unquote_splicing(arg_types)) :: :ok
          def unquote(name)(unquote_splicing(call_args)) do
            unquote(ok_value)
          end
        end

      always_false? ->
        error_value = if is_boolean(body), do: {:error, reason}, else: body

        quote do
          @spec unquote(check_fun_name)(Spek.context()) :: Spek.Literal.t()
          def unquote(check_fun_name)(args \\ unquote(check_args)) do
            %Spek.Literal{result: unquote(body), satisfied?: false}
          end

          @spec unquote(predicate_fun_name)(unquote_splicing(arg_types)) ::
                  false
          def unquote(predicate_fun_name)(unquote_splicing(call_args)) do
            false
          end

          @spec unquote(name)(unquote_splicing(arg_types)) ::
                  {:error, unquote(reason)}
          def unquote(name)(unquote_splicing(call_args)) do
            unquote(error_value)
          end
        end

      true ->
        quote generated: true do
          @spec unquote(check_fun_name)(Spek.context()) :: Spek.Check.t()
          def unquote(check_fun_name)(args \\ unquote(check_args)) do
            %Spek.Check{
              module: unquote(module),
              fun: unquote(name),
              args: args
            }
          end

          @spec unquote(predicate_fun_name)(unquote_splicing(arg_types)) ::
                  boolean()
          def unquote(predicate_fun_name)(unquote_splicing(call_args)) do
            Spek.to_boolean(unquote(name)(unquote_splicing(call_args)))
          end

          @spec unquote(name)(unquote_splicing(arg_types)) ::
                  :ok | {:error, unquote(reason)}
          def unquote(name)(unquote_splicing(call_args)) do
            case unquote(body) do
              true -> :ok
              false -> {:error, unquote(reason)}
              :ok -> :ok
              :error -> :error
              {:ok, _} = result -> result
              {:error, _} = result -> result
            end
          end
        end
    end
  end
end
