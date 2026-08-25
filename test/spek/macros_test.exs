defmodule Spek.MacrosTest do
  use ExUnit.Case

  alias __MODULE__.Checks
  alias Spek.Check
  alias Spek.Literal

  defmodule Device do
    @moduledoc false
    @enforce_keys [:id]
    defstruct [:id, :state]
  end

  defmodule Checks do
    import Spek.Macros

    alias Spek.MacrosTest.Device

    build_check(:user_active, [{:ctx, :state}, :active])
    build_check(:user_banned)

    defcheck account_balanced(account,
               args: [:ctx],
               reason: :account_unbalanced
             ) do
      account.balance >= 0
    end

    defcheck rich_atom(account, args: [:ctx]) do
      if account.balance >= 100_000, do: :ok, else: :error
    end

    defcheck rich_tuple(account, args: [:ctx]) do
      if account.balance >= 100_000, do: {:ok, :rich}, else: {:error, :not_rich}
    end

    defcheck matching_organization(user, organization,
               args: [{:ctx, :user}, {:ctx, :organization}],
               reason: :no_organization_match
             ) do
      user.organization_id == organization.id
    end

    defcheck charging(device) do
      device.charging?
    end

    defcheck two_args(one, two, args: [{:ctx, :one}, {:ctx, :two}]) do
      one == two
    end

    defcheck two_args_no_opts(one, two) do
      one == two
    end

    defcheck no_args_with_expression do
      1 == 1
    end

    defcheck always_true() do
      true
    end

    defcheck always_false do
      false
    end

    defcheck always_ok do
      :ok
    end

    defcheck always_error do
      :error
    end

    defcheck always_ok_tuple do
      {:ok, :good}
    end

    defcheck always_error_tuple do
      {:error, :bad}
    end

    defcheck with_default_arg(one, two \\ 2) do
      one < two
    end

    defcheck no_args_with_reason(reason: :not_today) do
      1 == 2
    end

    defcheck no_args_literal_with_reason(reason: :never) do
      false
    end

    defcheck longer_than_head([head | tail]) do
      length(tail) > head
    end

    defcheck always_true_with_arg(device) do
      true
    end

    defcheck always_false_with_arg(device, reason: :never_ready) do
      false
    end

    defcheck default_arg_with_min_args(one, two \\ 2, args: [:ctx]) do
      one < two
    end

    defcheck default_arg_with_max_args(one, two \\ 2,
               args: [{:ctx, :one}, {:ctx, :two}]
             ) do
      one < two
    end

    defcheck all_args_defaulted(one \\ 1) do
      one > 0
    end

    defcheck zero_arity_explicit_args(args: []) do
      1 == 1
    end

    defcheck three_args(a, b, c, args: [{:ctx, :a}, {:ctx, :b}, {:ctx, :c}]) do
      a == b and b == c
    end

    defcheck tagged_with_reason(account, reason: :unused) do
      if account.balance >= 0, do: :ok, else: {:error, :account_unbalanced}
    end

    defcheck first_positive([head | _]) do
      head > 0
    end

    defcheck device_active(%Device{state: state}) do
      state == :active
    end

    defcheck two_key_map(%{state: state} = device) do
      state == :active and map_size(device) == 2
    end

    defcheck positive(number) when is_integer(number) do
      number > 0
    end

    defcheck guarded_literal(device) when is_map(device) do
      true
    end

    defcheck guarded_with_default(low, high \\ 10)
             when is_integer(low) and is_integer(high) do
      low < high
    end

    defcheck passes_result_through(value) do
      value
    end
  end

  describe "build_check/2" do
    test "defines a function that returns a check struct" do
      assert Checks.user_active_check() == %Check{
               args: [{:ctx, :state}, :active],
               fun: :user_active,
               module: Spek.MacrosTest.Checks
             }
    end

    test "defaults args to [:ctx]" do
      assert Checks.user_banned_check() == %Check{
               args: [:ctx],
               fun: :user_banned,
               module: Spek.MacrosTest.Checks
             }
    end

    test "can override the default args" do
      assert Checks.user_active_check([{:ctx, :status}, :active]) == %Check{
               args: [{:ctx, :status}, :active],
               fun: :user_active,
               module: Spek.MacrosTest.Checks
             }
    end
  end

  describe "defcheck/3" do
    test "defines a function that returns a check struct" do
      assert Checks.account_balanced_check() == %Check{
               args: [:ctx],
               fun: :account_balanced,
               module: Spek.MacrosTest.Checks
             }
    end

    test "can override the check args" do
      assert Checks.account_balanced_check([{:ctx, :account}]) == %Check{
               args: [{:ctx, :account}],
               fun: :account_balanced,
               module: Spek.MacrosTest.Checks
             }
    end

    test "defines a predicate function" do
      assert Checks.account_balanced?(%{balance: 1}) == true
      assert Checks.account_balanced?(%{balance: -1}) == false
    end

    test "defines an ok/error function" do
      assert Checks.account_balanced(%{balance: 1}) == :ok

      assert Checks.account_balanced(%{balance: -1}) ==
               {:error, :account_unbalanced}
    end

    test "defines an predicate function with multiple arguments" do
      assert Checks.matching_organization?(%{organization_id: 1}, %{id: 1}) ==
               true

      assert Checks.matching_organization?(%{organization_id: 1}, %{id: 2}) ==
               false
    end

    test "defines an ok/error function with multiple arguments" do
      assert Checks.matching_organization(%{organization_id: 1}, %{id: 1}) ==
               :ok

      assert Checks.matching_organization(%{organization_id: 1}, %{id: 2}) ==
               {:error, :no_organization_match}
    end

    test "can define check without args and opts that is always true" do
      assert Checks.always_true_check() == %Spek.Literal{
               result: :ok,
               satisfied?: true
             }

      assert Checks.always_true?() == true
      assert Checks.always_true() == :ok
    end

    test "can define check without args and opts that is always false" do
      assert Checks.always_false_check() == %Spek.Literal{
               result: {:error, :failed},
               satisfied?: false
             }

      assert Checks.always_false?() == false
      assert Checks.always_false() == {:error, :failed}
    end

    test "can define check without args and opts that is always :ok" do
      assert Checks.always_ok_check() == %Spek.Literal{
               result: :ok,
               satisfied?: true
             }

      assert Checks.always_ok?() == true
      assert Checks.always_ok() == :ok
    end

    test "can define check without args and opts that is always :error" do
      assert Checks.always_error_check() == %Spek.Literal{
               result: :error,
               satisfied?: false
             }

      assert Checks.always_error?() == false
      assert Checks.always_error() == :error
    end

    test "can define check without args and opts that is always :ok tuple" do
      assert Checks.always_ok_tuple_check() == %Spek.Literal{
               result: {:ok, :good},
               satisfied?: true
             }

      assert Checks.always_ok_tuple?() == true
      assert Checks.always_ok_tuple() == {:ok, :good}
    end

    test "can define check without args and opts that is always :error tuple" do
      assert Checks.always_error_tuple_check() == %Spek.Literal{
               result: {:error, :bad},
               satisfied?: false
             }

      assert Checks.always_error_tuple?() == false
      assert Checks.always_error_tuple() == {:error, :bad}
    end

    test "can be called without arguments" do
      assert Checks.charging_check() == %Check{
               args: [:ctx],
               fun: :charging,
               module: Spek.MacrosTest.Checks
             }
    end

    test "supports function that returns :ok/:error atom" do
      assert Checks.rich_atom_check() == %Check{
               args: [:ctx],
               fun: :rich_atom,
               module: Spek.MacrosTest.Checks
             }

      assert Checks.rich_atom?(%{balance: 100_000}) == true
      assert Checks.rich_atom?(%{balance: 10_000}) == false

      assert Checks.rich_atom(%{balance: 100_000}) == :ok
      assert Checks.rich_atom(%{balance: 10_000}) == :error
    end

    test "supports function that returns :ok/:error tuple" do
      assert Checks.rich_tuple_check() == %Check{
               args: [:ctx],
               fun: :rich_tuple,
               module: Spek.MacrosTest.Checks
             }

      assert Checks.rich_tuple?(%{balance: 100_000}) == true
      assert Checks.rich_tuple?(%{balance: 10_000}) == false

      assert Checks.rich_tuple(%{balance: 100_000}) == {:ok, :rich}
      assert Checks.rich_tuple(%{balance: 10_000}) == {:error, :not_rich}
    end

    test "handles multiple arguments" do
      assert Checks.two_args(1, 1) == :ok
      assert Checks.two_args(1, 2) == {:error, :failed}
    end

    test "handles default arguments" do
      refute Checks.with_default_arg?(1, 1)
      assert Checks.with_default_arg?(1, 2)
      assert Checks.with_default_arg?(1, 3)
      assert Checks.with_default_arg?(1)
      refute Checks.with_default_arg?(3)
    end

    test "defaults :args to [] for zero-arity check functions" do
      assert Checks.no_args_with_expression_check() == %Check{
               args: [],
               fun: :no_args_with_expression,
               module: Spek.MacrosTest.Checks
             }

      assert Spek.eval?(Checks.no_args_with_expression_check()) == true
    end

    test "raises if the :args option does not match the function arity" do
      assert_raise ArgumentError, ~r/Got 2 element\(s\)/, fn ->
        defmodule BadArgsArity do
          import Spek.Macros

          defcheck mismatched(account, args: [:ctx, :ctx]) do
            account.balance >= 0
          end
        end
      end
    end

    test "omits the :args default for multi-argument check functions" do
      assert Checks.two_args_no_opts_check([{:ctx, :one}, {:ctx, :two}]) ==
               %Check{
                 args: [{:ctx, :one}, {:ctx, :two}],
                 fun: :two_args_no_opts,
                 module: Spek.MacrosTest.Checks
               }

      refute function_exported?(Checks, :two_args_no_opts_check, 0)
    end

    test "accepts options for a check without arguments" do
      assert Checks.no_args_with_reason() == {:error, :not_today}
      assert Checks.no_args_with_reason?() == false

      assert Checks.no_args_with_reason_check() == %Check{
               args: [],
               fun: :no_args_with_reason,
               module: Spek.MacrosTest.Checks
             }
    end

    test "accepts options for a check without arguments and a literal body" do
      assert Checks.no_args_literal_with_reason() == {:error, :never}
      assert Checks.no_args_literal_with_reason?() == false
    end

    test "treats a list argument as an argument, not as options" do
      assert Checks.longer_than_head?([1, :a, :b]) == true
      assert Checks.longer_than_head([5, :a, :b]) == {:error, :failed}

      assert Checks.longer_than_head_check() == %Check{
               args: [:ctx],
               fun: :longer_than_head,
               module: Spek.MacrosTest.Checks
             }
    end

    test "raises if the :args option is not a list" do
      assert_raise ArgumentError,
                   ~r/invalid :args option.*Expected a list/s,
                   fn ->
                     defmodule NonListArgs do
                       import Spek.Macros

                       defcheck bad_args(account, args: :ctx) do
                         account.balance >= 0
                       end
                     end
                   end
    end

    test "raises if a check is defined more than once" do
      assert_raise ArgumentError, ~r/duplicate check definition/, fn ->
        defmodule MultipleClauses do
          import Spek.Macros

          defcheck state(:active) do
            true
          end

          defcheck state(:inactive) do
            false
          end
        end
      end
    end

    test "raises the same error as a hand-written check for an invalid result" do
      message = ~r/invalid check function result.*passes_result_through/s

      assert_raise ArgumentError, message, fn ->
        Checks.passes_result_through(nil)
      end

      assert_raise ArgumentError, message, fn ->
        Checks.passes_result_through?(nil)
      end

      assert_raise ArgumentError, message, fn ->
        Spek.eval?(Checks.passes_result_through_check(), nil)
      end
    end

    test "raises for an unknown option" do
      assert_raise ArgumentError,
                   ~r/unknown option in defcheck typo.*:resaon/s,
                   fn ->
                     defmodule UnknownOption do
                       import Spek.Macros

                       defcheck typo(account, resaon: :account_unbalanced) do
                         account.balance >= 0
                       end
                     end
                   end
    end

    test "raises for a keyword list in the last argument position" do
      assert_raise ArgumentError,
                   ~r/unknown option in defcheck has_role.*:role.*argument pattern/s,
                   fn ->
                     defmodule KeywordArgument do
                       import Spek.Macros

                       defcheck has_role(role: role) do
                         role == :admin
                       end
                     end
                   end
    end

    test "handles a literal body with arguments" do
      assert Checks.always_true_with_arg?(:anything) == true
      assert Checks.always_true_with_arg(:anything) == :ok

      assert Checks.always_true_with_arg_check() == %Literal{
               result: :ok,
               satisfied?: true
             }

      assert Checks.always_false_with_arg?(:anything) == false
      assert Checks.always_false_with_arg(:anything) == {:error, :never_ready}

      assert Checks.always_false_with_arg_check() == %Literal{
               result: {:error, :never_ready},
               satisfied?: false
             }
    end

    test "collects the declared reason of a constant check" do
      rule =
        Spek.all_of([
          Checks.always_false_with_arg_check(),
          Checks.account_balanced_check()
        ])

      assert {:error, %Spek.EvaluationError{results: results}} =
               Spek.eval_collect_all(rule, %{balance: -1})

      assert Enum.sort(results) == [:account_unbalanced, :never_ready]
    end

    test "accepts :args matching the minimum arity of a defaulted function" do
      assert Checks.default_arg_with_min_args?(1) == true
      assert Checks.default_arg_with_min_args?(1, 0) == false

      assert Checks.default_arg_with_min_args_check() == %Check{
               args: [:ctx],
               fun: :default_arg_with_min_args,
               module: Spek.MacrosTest.Checks
             }
    end

    test "accepts :args matching the maximum arity of a defaulted function" do
      assert Checks.default_arg_with_max_args?(1) == true

      assert Checks.default_arg_with_max_args_check() == %Check{
               args: [{:ctx, :one}, {:ctx, :two}],
               fun: :default_arg_with_max_args,
               module: Spek.MacrosTest.Checks
             }
    end

    test "handles a function whose arguments are all defaulted" do
      assert Checks.all_args_defaulted?() == true
      assert Checks.all_args_defaulted?(-1) == false

      assert Checks.all_args_defaulted_check() == %Check{
               args: [:ctx],
               fun: :all_args_defaulted,
               module: Spek.MacrosTest.Checks
             }
    end

    test "accepts an explicit empty :args for a zero-arity check" do
      assert Checks.zero_arity_explicit_args?() == true

      assert Checks.zero_arity_explicit_args_check() == %Check{
               args: [],
               fun: :zero_arity_explicit_args,
               module: Spek.MacrosTest.Checks
             }
    end

    test "accepts an argument pattern that is not a valid expression" do
      assert Checks.first_positive?([1, 2]) == true
      assert Checks.first_positive([-1, 2]) == {:error, :failed}
    end

    test "accepts a struct pattern for a struct with enforced keys" do
      device = %Device{id: 1, state: :active}

      assert Checks.device_active?(device) == true

      assert Checks.device_active(%Device{id: 1, state: :idle}) ==
               {:error, :failed}
    end

    test "accepts a pattern that also binds the whole argument" do
      assert Checks.two_key_map?(%{state: :active, id: 1}) == true
      assert Checks.two_key_map?(%{state: :active, id: 1, extra: 1}) == false
    end

    test "raises from the check function if the pattern does not match" do
      assert_raise FunctionClauseError, ~r/Checks\.device_active\/1/, fn ->
        Checks.device_active?(%{})
      end
    end

    test "supports guards" do
      assert Checks.positive?(1) == true
      assert Checks.positive?(-1) == false
      assert Checks.positive(1) == :ok
      assert Checks.positive(-1) == {:error, :failed}

      assert Checks.positive_check() == %Check{
               args: [:ctx],
               fun: :positive,
               module: Spek.MacrosTest.Checks
             }
    end

    test "raises from the check function if the guard does not match" do
      assert_raise FunctionClauseError, ~r/Checks\.positive\/1/, fn ->
        Checks.positive?(:not_an_integer)
      end
    end

    test "supports guards on a literal do-block" do
      assert Checks.guarded_literal?(%{}) == true
      assert Checks.guarded_literal(%{}) == :ok

      assert_raise FunctionClauseError, fn ->
        Checks.guarded_literal?(:not_a_map)
      end
    end

    test "supports guards combined with default arguments" do
      assert Checks.guarded_with_default?(1) == true
      assert Checks.guarded_with_default?(1, 0) == false

      assert_raise FunctionClauseError, fn ->
        Checks.guarded_with_default?(:not_an_integer)
      end
    end

    test "ignores :reason if the do-block returns a tagged result" do
      assert Checks.tagged_with_reason(%{balance: 1}) == :ok

      assert Checks.tagged_with_reason(%{balance: -1}) ==
               {:error, :account_unbalanced}
    end

    test "handles more than two arguments" do
      assert Checks.three_args?(1, 1, 1) == true
      assert Checks.three_args(1, 1, 2) == {:error, :failed}

      assert Checks.three_args_check() == %Check{
               args: [{:ctx, :a}, {:ctx, :b}, {:ctx, :c}],
               fun: :three_args,
               module: Spek.MacrosTest.Checks
             }
    end
  end
end
