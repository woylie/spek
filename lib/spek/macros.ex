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

  This will compile a `{fun}_check` function like this:

      def active_user_check(args \\\\ [:ctx]) do
        %Check{module: MyApp.MyModule, fun: :active_user, args: args}
      end

  You can then use this function when building complex rules:

      Spek.all_of([
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
  @doc since: "0.1.0"
  defmacro build_check(fun, args \\ [:ctx]) do
    module = __CALLER__.module
    function_name = :"#{fun}_check"

    quote do
      @spec unquote(function_name)(Spek.Check.args()) :: Spek.Check.t()
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

  - `{name}?` - A predicate function that returns the result of the boolean
    expression defined in the do-block.
  - `{name}` - A function that runs the expression defined in the
    do-block and returns `:ok`, `:error`, `{:ok, term}`, or `{:error, term}`.
  - `{name}_check` - A function that returns a `Spek.Check` struct.

  `{name}?` and `{name}` take the arguments of the check definition. The
  arguments may be patterns, and the definition may have a guard. Both apply to
  `{name}` alone, since `{name}?` delegates to it, so an argument that does not
  match the pattern or does not satisfy the guard raises a
  `FunctionClauseError` naming `{name}`.

      defcheck positive(number) when is_integer(number) do
        number > 0
      end

  ## Options

  - `:args` - The list of arguments as used in the `Spek.Check` struct. Its
    length must match an arity of the check function, or an `ArgumentError` is
    raised at compile time. Defaults to `[:ctx]` for a check that takes one
    argument, and to `[]` for one that takes none.
  - `:reason` - The reason used in the error tuple. Defaults to `:failed`. This
    value is only used if the do-block returns a boolean.

  A check that always takes two or more arguments has no default `:args`, so
  `{name}_check/1` is generated without a default argument and the arguments
  are passed at every call site.

  Options are passed as the last argument of the check definition. They are
  recognized as a keyword list rather than by position, so a check without
  arguments can take options too.

      defcheck maintenance_mode(reason: :under_maintenance) do
        Application.get_env(:my_app, :maintenance_mode, false)
      end

  An unrecognized option raises an `ArgumentError` at compile time.

  ## Do-block

  The do-block is required to return a boolean, `:ok`, `:error`, `{:ok, term}`,
  or `{:error, term}`.

  ## Example

  This macro call:

      defmodule MyApp.MyModule do
        import Spek.Macros

        defcheck account_balanced(account, reason: :account_unbalanced) do
          account.balance >= 0
        end
      end

  Will result in these three functions:

      def account_balanced?(account) do
        Spek.to_boolean(account_balanced(account))
      end

      def account_balanced(account) do
        if account.balance >= 0,
          do: :ok,
          else: {:error, :account_unbalanced}
      end

      def account_balanced_check(args \\\\ [:ctx]) do
        %Check{module: MyApp.MyModule, fun: :account_balanced, args: args}
      end

  The do-block can return `:ok` and `:error` values instead of a boolean, with
  the same result:

      defcheck account_balanced(account) do
        if account.balance >= 0, do: :ok, else: {:error, :account_unbalanced}
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

  Passing arguments to `account_balanced_check/1` overrides the default, e.g. if
  you combine checks that work on different data. With
  `account_balanced_check([{:ctx, :account}])` in the rule above, the check
  receives the `:account` key of the context instead of the whole context:

      Spek.eval(transfer_rule(), account: %Account{balance: 100})

  A check can take any number of arguments. With two or more, the arguments are
  passed when the check is built, or given as the `:args` option:

      defcheck matching_organization(user, organization,
                 reason: :no_organization_match
               ) do
        user.organization_id == organization.id
      end

      Spek.eval(
        matching_organization_check([{:ctx, :user}, {:ctx, :organization}]),
        user: %User{organization_id: 1},
        organization: %Organization{id: 1}
      )
  """
  @doc since: "0.1.0"
  defmacro defcheck({:when, _, [{name, _, raw_args}, guard]}, do: body) do
    expand_defcheck(name, raw_args, guard, body, __CALLER__.module)
  end

  defmacro defcheck({name, _, raw_args}, do: body) do
    expand_defcheck(name, raw_args, nil, body, __CALLER__.module)
  end

  # credo:disable-for-next-line
  defp expand_defcheck(name, raw_args, guard, body, module) do
    {call_args, opts} = split_call_args(raw_args || [])
    validate_opts!(name, opts)
    register_name!(module, name)

    max_arity = length(call_args)
    num_defaults = Enum.count(call_args, &match?({:\\, _, _}, &1))
    min_arity = max_arity - num_defaults

    reason = Keyword.get(opts, :reason, :failed)
    check_fun_name = :"#{name}_check"
    predicate_fun_name = :"#{name}?"

    check_head =
      build_check_head(name, check_fun_name, opts, min_arity, max_arity)

    arg_types =
      for _ <- call_args do
        quote(do: term())
      end

    fresh_args = Macro.generate_arguments(max_arity, __MODULE__)

    predicate_head_args =
      call_args
      |> Enum.zip(fresh_args)
      |> Enum.map(fn
        {{:\\, meta, [_arg, default]}, fresh} -> {:\\, meta, [fresh, default]}
        {_arg, fresh} -> fresh
      end)

    unused_call_args = mark_generated(call_args)

    literal_predicate_head =
      build_head(predicate_fun_name, unused_call_args, guard)

    literal_name_head = build_head(name, unused_call_args, guard)
    predicate_head = build_head(predicate_fun_name, predicate_head_args, nil)
    name_head = build_head(name, call_args, guard)

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

        quote generated: true do
          @spec unquote(check_fun_name)(Spek.Check.args()) :: Spek.Literal.t()
          def unquote(check_head) do
            %Spek.Literal{result: unquote(body), satisfied?: true}
          end

          @spec unquote(predicate_fun_name)(unquote_splicing(arg_types)) :: true
          def unquote(literal_predicate_head) do
            true
          end

          @spec unquote(name)(unquote_splicing(arg_types)) :: :ok
          def unquote(literal_name_head) do
            unquote(ok_value)
          end
        end

      always_false? ->
        error_value = if is_boolean(body), do: {:error, reason}, else: body

        quote generated: true do
          @spec unquote(check_fun_name)(Spek.Check.args()) :: Spek.Literal.t()
          def unquote(check_head) do
            %Spek.Literal{result: unquote(body), satisfied?: false}
          end

          @spec unquote(predicate_fun_name)(unquote_splicing(arg_types)) ::
                  false
          def unquote(literal_predicate_head) do
            false
          end

          @spec unquote(name)(unquote_splicing(arg_types)) ::
                  {:error, unquote(reason)}
          def unquote(literal_name_head) do
            unquote(error_value)
          end
        end

      true ->
        quote generated: true do
          @spec unquote(check_fun_name)(Spek.Check.args()) :: Spek.Check.t()
          def unquote(check_head) do
            %Spek.Check{
              module: unquote(module),
              fun: unquote(name),
              args: args
            }
          end

          @spec unquote(predicate_fun_name)(unquote_splicing(arg_types)) ::
                  boolean()
          def unquote(predicate_head) do
            Spek.to_boolean(unquote(name)(unquote_splicing(fresh_args)))
          end

          @spec unquote(name)(unquote_splicing(arg_types)) :: Spek.result()
          def unquote(name_head) do
            case unquote(body) do
              true ->
                :ok

              false ->
                {:error, unquote(reason)}

              :ok ->
                :ok

              :error ->
                :error

              {:ok, _} = result ->
                result

              {:error, _} = result ->
                result

              other ->
                Spek.__invalid_check_result__!(
                  unquote(module),
                  unquote(name),
                  other
                )
            end
          end
        end
    end
  end

  @known_opts [:args, :reason]

  defp build_head(name, args, nil) do
    quote(do: unquote(name)(unquote_splicing(args)))
  end

  defp build_head(name, args, guard) do
    quote(do: unquote(name)(unquote_splicing(args)) when unquote(guard))
  end

  defp build_check_head(name, check_fun_name, opts, min_arity, max_arity) do
    case Keyword.fetch(opts, :args) do
      {:ok, check_args} ->
        validate_check_args!(name, check_args, min_arity, max_arity)
        quote(do: unquote(check_fun_name)(args \\ unquote(check_args)))

      :error when min_arity <= 1 ->
        check_args = if max_arity >= 1, do: [:ctx], else: []
        quote(do: unquote(check_fun_name)(args \\ unquote(check_args)))

      :error ->
        quote(do: unquote(check_fun_name)(args))
    end
  end

  defp validate_check_args!(name, check_args, min_arity, max_arity) do
    if not is_list(check_args) do
      raise ArgumentError, """
      invalid :args option in defcheck #{name}

      Expected a list.

      Got:

          #{inspect(check_args)}
      """
    end

    if length(check_args) not in min_arity..max_arity//1 do
      arity_range =
        if min_arity == max_arity,
          do: "#{max_arity}",
          else: "#{min_arity} to #{max_arity}"

      raise ArgumentError, """
      invalid :args option in defcheck #{name}

      Expected #{arity_range} element(s), to match the arity of #{name}.

      Got #{length(check_args)} element(s):

          #{inspect(check_args)}
      """
    end
  end

  defp mark_generated(ast) do
    Macro.prewalk(ast, fn node ->
      Macro.update_meta(node, &Keyword.put(&1, :generated, true))
    end)
  end

  defp split_call_args([]), do: {[], []}

  defp split_call_args(args) do
    last = List.last(args)

    if last != [] and Keyword.keyword?(last) do
      {Enum.drop(args, -1), last}
    else
      {args, []}
    end
  end

  # defcheck emits a whole `{name}_check/1` function, not a clause of one, so a
  # check cannot be defined in multiple clauses.
  defp register_name!(module, name) do
    defined = Module.get_attribute(module, :spek_defcheck_names) || []

    if name in defined do
      raise ArgumentError, """
      duplicate check definition

      #{name} is already defined in this module, and a check cannot be split
      into multiple clauses: the generated #{name}_check/1 function would be
      defined more than once.

      Use a single clause and pattern match inside the do-block.
      """
    end

    Module.put_attribute(module, :spek_defcheck_names, [name | defined])
  end

  defp validate_opts!(name, opts) do
    case Keyword.drop(opts, @known_opts) do
      [] ->
        :ok

      unknown ->
        keys = unknown |> Keyword.keys() |> Enum.map_join(", ", &inspect/1)

        raise ArgumentError, """
        unknown option in defcheck #{name}

        Expected one of:

            - :args
            - :reason

        Got:

            #{keys}
        """
    end
  end
end
