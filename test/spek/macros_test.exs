defmodule Spek.MacrosTest do
  use ExUnit.Case

  alias __MODULE__.Checks
  alias Spek.Check

  defmodule Checks do
    import Spek.Macros

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

    defcheck two_args_no_opts(one, two) do
      one == two
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
               result: true,
               satisfied?: true
             }

      assert Checks.always_true?() == true
      assert Checks.always_true() == :ok
    end

    test "can define check without args and opts that is always false" do
      assert Checks.always_false_check() == %Spek.Literal{
               result: false,
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

    test "handles multiple arguments without options" do
      assert Checks.two_args_no_opts(1, 1) == :ok
      assert Checks.two_args_no_opts(1, 2) == {:error, :failed}
    end

    test "handles default arguments" do
      refute Checks.with_default_arg?(1, 1)
      assert Checks.with_default_arg?(1, 2)
      assert Checks.with_default_arg?(1, 3)
      assert Checks.with_default_arg?(1)
      refute Checks.with_default_arg?(3)
    end
  end
end
