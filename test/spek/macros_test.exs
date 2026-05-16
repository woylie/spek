defmodule Spek.MacrosTest do
  use ExUnit.Case

  alias __MODULE__.Checks
  alias Spek.Check

  defmodule Checks do
    import Spek.Macros

    build_check(:user_active, [{:ctx, :state}, :active])

    defcheck account_balanced(account,
               args: [:ctx],
               reason: :account_unbalanced
             ) do
      account.balance >= 0
    end

    defcheck matching_organization(user, organization,
               args: [{:ctx, :user}, {:ctx, :organization}],
               reason: :no_organization_match
             ) do
      user.organization_id == organization.id
    end

    defcheck always_true() do
      true
    end

    defcheck always_false do
      false
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
  end
end
