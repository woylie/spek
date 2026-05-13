defmodule Spek.EvaluatorTest do
  use ExUnit.Case, async: true

  alias Spek.And
  alias Spek.Check
  alias Spek.Checks
  alias Spek.Evaluator
  alias Spek.Literal
  alias Spek.Not
  alias Spek.Or

  describe "evaluate_expression/4" do
    test "evaluates literal" do
      assert Evaluator.evaluate_expression(%Literal{satisfied?: true}) == true
      assert Evaluator.evaluate_expression(%Literal{satisfied?: false}) == false
    end

    test "evaluates check without arg" do
      assert Evaluator.evaluate_expression(%Check{
               module: Checks,
               fun: :always_true,
               args: []
             }) == true

      assert Evaluator.evaluate_expression(%Check{
               module: Checks,
               fun: :always_false,
               args: []
             }) == false
    end

    test "valuates check with arg that returns no boolean" do
      test_cases = [
        # check return value, expected result
        {:ok, true},
        {:error, false},
        {{:ok, "msg"}, true},
        {{:error, "msg"}, false}
      ]

      for {value, expected_result} <- test_cases do
        assert Evaluator.evaluate_expression(%Check{
                 module: Checks,
                 fun: :return_arg,
                 args: [value]
               }) == expected_result
      end
    end

    test "evaluates check that takes whole context as arg" do
      assert Evaluator.evaluate_expression(
               %Check{
                 module: Checks,
                 fun: :from_result_key,
                 args: [:ctx]
               },
               %{result: true}
             ) == true

      assert Evaluator.evaluate_expression(
               %Check{
                 module: Checks,
                 fun: :from_result_key,
                 args: [:ctx]
               },
               %{result: false}
             ) == false
    end

    test "evaluates check that takes value from context map as arg" do
      assert Evaluator.evaluate_expression(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               %{result: true}
             ) == true

      assert Evaluator.evaluate_expression(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               %{result: false}
             ) == false
    end

    test "evaluates check that takes value from context keyword list as arg" do
      assert Evaluator.evaluate_expression(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               result: true
             ) == true

      assert Evaluator.evaluate_expression(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               result: false
             ) == false
    end

    test "evaluates not" do
      assert Evaluator.evaluate_expression(%Not{
               expression: %Literal{satisfied?: true, value: :ok}
             }) == false

      assert Evaluator.evaluate_expression(%Not{
               expression: %Literal{satisfied?: false, value: :error}
             }) == true
    end

    test "evaluates And without children" do
      assert Evaluator.evaluate_expression(%And{children: []}) == true
    end

    test "evaluates And with one child" do
      assert Evaluator.evaluate_expression(%And{
               children: [%Literal{satisfied?: true, value: :ok}]
             }) == true

      assert Evaluator.evaluate_expression(%And{
               children: [%Literal{satisfied?: false, value: :error}]
             }) == false
    end

    test "evaluates And with two children" do
      test_cases = [
        # first child, second child, expected result
        {true, true, true},
        {true, false, false},
        {false, true, false},
        {false, false, false}
      ]

      for {v1, v2, expected} <- test_cases do
        assert Evaluator.evaluate_expression(%And{
                 children: [
                   %Literal{satisfied?: v1},
                   %Literal{satisfied?: v2}
                 ]
               }) == expected
      end
    end

    test "evaluates Or without children" do
      assert Evaluator.evaluate_expression(%Or{children: []}) == false
    end

    test "evaluates Or with one child" do
      assert Evaluator.evaluate_expression(%Or{
               children: [%Literal{satisfied?: true}]
             }) == true

      assert Evaluator.evaluate_expression(%Or{
               children: [%Literal{satisfied?: false}]
             }) == false
    end

    test "evaluates Or with two children" do
      test_cases = [
        # first child, second child, expected result
        {true, true, true},
        {true, false, true},
        {false, true, true},
        {false, false, false}
      ]

      for {v1, v2, expected} <- test_cases do
        assert Evaluator.evaluate_expression(%Or{
                 children: [
                   %Literal{satisfied?: v1},
                   %Literal{satisfied?: v2}
                 ]
               }) == expected
      end
    end
  end

  describe "evaluate_expression_acc/4" do
    test "evaluates literal" do
      assert Evaluator.evaluate_expression_acc(%Literal{satisfied?: true}) ==
               %Literal{satisfied?: true}

      assert Evaluator.evaluate_expression_acc(%Literal{satisfied?: false}) ==
               %Literal{satisfied?: false}
    end

    test "evaluates check without arg" do
      assert Evaluator.evaluate_expression_acc(%Check{
               module: Checks,
               fun: :always_true,
               args: []
             }) == %Check{
               module: Checks,
               fun: :always_true,
               args: [],
               satisfied?: true,
               result: true
             }

      assert Evaluator.evaluate_expression_acc(%Check{
               module: Checks,
               fun: :always_false,
               args: []
             }) == %Check{
               module: Checks,
               fun: :always_false,
               args: [],
               satisfied?: false,
               result: false
             }
    end

    test "evaluates check with arg that returns no boolean" do
      test_cases = [
        # check return value, expected result
        {:ok, true},
        {:error, false},
        {{:ok, "msg"}, true},
        {{:error, "msg"}, false}
      ]

      for {value, expected_result} <- test_cases do
        assert Evaluator.evaluate_expression_acc(%Check{
                 module: Checks,
                 fun: :return_arg,
                 args: [value]
               }) == %Check{
                 module: Checks,
                 fun: :return_arg,
                 args: [value],
                 satisfied?: expected_result,
                 result: value
               }
      end
    end

    test "evaluates check that takes whole context as arg" do
      assert Evaluator.evaluate_expression_acc(
               %Check{
                 module: Checks,
                 fun: :from_result_key,
                 args: [:ctx]
               },
               %{result: true}
             ) == %Check{
               module: Checks,
               fun: :from_result_key,
               args: [:ctx],
               result: true,
               satisfied?: true
             }

      assert Evaluator.evaluate_expression_acc(
               %Check{
                 module: Checks,
                 fun: :from_result_key,
                 args: [:ctx]
               },
               %{result: false}
             ) == %Check{
               module: Checks,
               fun: :from_result_key,
               args: [:ctx],
               result: false,
               satisfied?: false
             }
    end

    test "evaluates check that takes value from context map as arg" do
      assert Evaluator.evaluate_expression_acc(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               %{result: true}
             ) == %Check{
               module: Checks,
               fun: :from_bool,
               args: [{:ctx, :result}],
               result: :ok,
               satisfied?: true
             }

      assert Evaluator.evaluate_expression_acc(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               %{result: false}
             ) == %Check{
               module: Checks,
               fun: :from_bool,
               args: [{:ctx, :result}],
               result: :error,
               satisfied?: false
             }
    end

    test "evaluates check that takes value from context keyword list as arg" do
      assert Evaluator.evaluate_expression_acc(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               result: true
             ) == %Check{
               module: Checks,
               fun: :from_bool,
               args: [{:ctx, :result}],
               result: :ok,
               satisfied?: true
             }

      assert Evaluator.evaluate_expression_acc(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               result: false
             ) == %Check{
               module: Checks,
               fun: :from_bool,
               args: [{:ctx, :result}],
               result: :error,
               satisfied?: false
             }
    end

    test "evaluates not with literal" do
      assert Evaluator.evaluate_expression_acc(%Not{
               expression: %Literal{satisfied?: true}
             }) == %Not{
               expression: %Literal{satisfied?: true},
               satisfied?: false
             }

      assert Evaluator.evaluate_expression_acc(%Not{
               expression: %Literal{satisfied?: false}
             }) == %Not{
               expression: %Literal{satisfied?: false},
               satisfied?: true
             }
    end

    test "evaluates not with check" do
      assert Evaluator.evaluate_expression_acc(
               %Not{
                 expression: %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [{:ctx, :result}]
                 }
               },
               result: :ok
             ) == %Not{
               expression: %Check{
                 satisfied?: true,
                 module: Checks,
                 fun: :return_arg,
                 args: [{:ctx, :result}],
                 result: :ok
               },
               satisfied?: false
             }

      assert Evaluator.evaluate_expression_acc(
               %Not{
                 expression: %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [{:ctx, :result}]
                 }
               },
               result: {:error, :failed}
             ) == %Not{
               expression: %Check{
                 satisfied?: false,
                 module: Checks,
                 fun: :return_arg,
                 args: [{:ctx, :result}],
                 result: {:error, :failed}
               },
               satisfied?: true
             }
    end

    test "evaluates And without children" do
      assert Evaluator.evaluate_expression_acc(%And{children: []}) == %And{
               children: [],
               satisfied?: true
             }
    end

    test "evaluates And with one child" do
      assert Evaluator.evaluate_expression_acc(%And{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:ok]}
               ]
             }) == %And{
               children: [
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [:ok],
                   result: :ok,
                   satisfied?: true
                 }
               ],
               satisfied?: true
             }

      assert Evaluator.evaluate_expression_acc(%And{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:error]}
               ]
             }) == %And{
               children: [
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [:error],
                   result: :error,
                   satisfied?: false
                 }
               ],
               satisfied?: false
             }
    end

    test "evaluates And with two children" do
      # all checks true
      assert Evaluator.evaluate_expression_acc(%And{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:ok]},
                 %Check{module: Checks, fun: :return_arg, args: [true]}
               ]
             }) == %And{
               children: [
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [:ok],
                   result: :ok,
                   satisfied?: true
                 },
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [true],
                   result: true,
                   satisfied?: true
                 }
               ],
               satisfied?: true
             }

      # first check true, second check false
      assert Evaluator.evaluate_expression_acc(%And{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:ok]},
                 %Check{module: Checks, fun: :return_arg, args: [false]}
               ]
             }) == %And{
               children: [
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [:ok],
                   result: :ok,
                   satisfied?: true
                 },
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [false],
                   result: false,
                   satisfied?: false
                 }
               ],
               satisfied?: false
             }

      # first checks false; second check shouldn't have been evaluated
      assert Evaluator.evaluate_expression_acc(%And{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:error]},
                 %Check{module: Checks, fun: :return_arg, args: [true]}
               ]
             }) == %And{
               children: [
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [:error],
                   result: :error,
                   satisfied?: false
                 }
               ],
               satisfied?: false
             }
    end

    test "evaluates Or without children" do
      assert Evaluator.evaluate_expression_acc(%Or{children: []}) == %Or{
               children: [],
               satisfied?: false
             }
    end

    test "evaluates Or with one child" do
      assert Evaluator.evaluate_expression_acc(%Or{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:ok]}
               ]
             }) == %Or{
               children: [
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [:ok],
                   result: :ok,
                   satisfied?: true
                 }
               ],
               satisfied?: true
             }

      assert Evaluator.evaluate_expression_acc(%Or{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:error]}
               ]
             }) == %Or{
               children: [
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [:error],
                   result: :error,
                   satisfied?: false
                 }
               ],
               satisfied?: false
             }
    end

    test "evaluates Or with two children" do
      # first check true, second check shouldn't have been evaluated
      assert Evaluator.evaluate_expression_acc(%Or{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:ok]},
                 %Check{module: Checks, fun: :return_arg, args: [:error]}
               ]
             }) == %Or{
               children: [
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [:ok],
                   result: :ok,
                   satisfied?: true
                 }
               ],
               satisfied?: true
             }

      # first check false, second check true
      assert Evaluator.evaluate_expression_acc(%Or{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:error]},
                 %Check{module: Checks, fun: :return_arg, args: [:ok]}
               ]
             }) == %Or{
               children: [
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [:error],
                   result: :error,
                   satisfied?: false
                 },
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [:ok],
                   result: :ok,
                   satisfied?: true
                 }
               ],
               satisfied?: true
             }

      # all checks false
      assert Evaluator.evaluate_expression_acc(%Or{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:error]},
                 %Check{module: Checks, fun: :return_arg, args: [false]}
               ]
             }) == %Or{
               children: [
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [:error],
                   result: :error,
                   satisfied?: false
                 },
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [false],
                   result: false,
                   satisfied?: false
                 }
               ],
               satisfied?: false
             }
    end
  end
end
