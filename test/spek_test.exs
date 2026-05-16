defmodule SpekTest do
  use ExUnit.Case

  alias Spek.AllOf
  alias Spek.AnyOf
  alias Spek.Check
  alias Spek.Checks
  alias Spek.EvaluationError
  alias Spek.Literal
  alias Spek.Not

  doctest Spek, import: true

  describe "eval?/2" do
    test "evaluates literal" do
      assert Spek.eval?(%Literal{satisfied?: true}) == true
      assert Spek.eval?(%Literal{satisfied?: false}) == false
    end

    test "evaluates check without arg" do
      assert Spek.eval?(%Check{
               module: Checks,
               fun: :always_true,
               args: []
             }) == true

      assert Spek.eval?(%Check{
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
        assert Spek.eval?(%Check{
                 module: Checks,
                 fun: :return_arg,
                 args: [value]
               }) == expected_result
      end
    end

    test "evaluates check that takes whole context as arg" do
      assert Spek.eval?(
               %Check{
                 module: Checks,
                 fun: :from_result_key,
                 args: [:ctx]
               },
               %{result: true}
             ) == true

      assert Spek.eval?(
               %Check{
                 module: Checks,
                 fun: :from_result_key,
                 args: [:ctx]
               },
               %{result: false}
             ) == false
    end

    test "evaluates check that takes value from context map as arg" do
      assert Spek.eval?(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               %{result: true}
             ) == true

      assert Spek.eval?(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               %{result: false}
             ) == false
    end

    test "evaluates check that takes value from context keyword list as arg" do
      assert Spek.eval?(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               result: true
             ) == true

      assert Spek.eval?(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               result: false
             ) == false
    end

    test "evaluates not" do
      assert Spek.eval?(%Not{
               expression: %Literal{satisfied?: true, result: :ok}
             }) == false

      assert Spek.eval?(%Not{
               expression: %Literal{satisfied?: false, result: :error}
             }) == true
    end

    test "evaluates And without children" do
      assert Spek.eval?(%AllOf{children: []}) == true
    end

    test "evaluates And with one child" do
      assert Spek.eval?(%AllOf{
               children: [%Literal{satisfied?: true, result: :ok}]
             }) == true

      assert Spek.eval?(%AllOf{
               children: [%Literal{satisfied?: false, result: :error}]
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
        assert Spek.eval?(%AllOf{
                 children: [
                   %Literal{satisfied?: v1},
                   %Literal{satisfied?: v2}
                 ]
               }) == expected
      end
    end

    test "evaluates Or without children" do
      assert Spek.eval?(%AnyOf{children: []}) == false
    end

    test "evaluates Or with one child" do
      assert Spek.eval?(%AnyOf{
               children: [%Literal{satisfied?: true}]
             }) == true

      assert Spek.eval?(%AnyOf{
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
        assert Spek.eval?(%AnyOf{
                 children: [
                   %Literal{satisfied?: v1},
                   %Literal{satisfied?: v2}
                 ]
               }) == expected
      end
    end
  end

  describe "eval_tree/2" do
    test "evaluates literal" do
      assert Spek.eval_tree(%Literal{satisfied?: true}) ==
               {:ok, %Literal{satisfied?: true}}

      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(%Literal{satisfied?: false})

      assert expression ==
               %Literal{satisfied?: false}
    end

    test "evaluates check without arg" do
      assert Spek.eval_tree(%Check{
               module: Checks,
               fun: :always_true,
               args: []
             }) ==
               {:ok,
                %Check{
                  module: Checks,
                  fun: :always_true,
                  args: [],
                  satisfied?: true,
                  result: true
                }}

      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(%Check{
                 module: Checks,
                 fun: :always_false,
                 args: []
               })

      assert expression == %Check{
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
        result =
          Spek.eval_tree(%Check{
            module: Checks,
            fun: :return_arg,
            args: [value]
          })

        expected_expression = %Check{
          module: Checks,
          fun: :return_arg,
          args: [value],
          satisfied?: expected_result,
          result: value
        }

        if expected_result do
          assert result == {:ok, expected_expression}
        else
          assert {:error, %EvaluationError{expression: ^expected_expression}} =
                   result
        end
      end
    end

    test "evaluates check that takes whole context as arg" do
      assert Spek.eval_tree(
               %Check{
                 module: Checks,
                 fun: :from_result_key,
                 args: [:ctx]
               },
               %{result: true}
             ) ==
               {:ok,
                %Check{
                  module: Checks,
                  fun: :from_result_key,
                  args: [:ctx],
                  result: true,
                  satisfied?: true
                }}

      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(
                 %Check{
                   module: Checks,
                   fun: :from_result_key,
                   args: [:ctx]
                 },
                 %{result: false}
               )

      assert expression == %Check{
               module: Checks,
               fun: :from_result_key,
               args: [:ctx],
               result: false,
               satisfied?: false
             }
    end

    test "evaluates check that takes value from context map as arg" do
      assert Spek.eval_tree(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               %{result: true}
             ) ==
               {:ok,
                %Check{
                  module: Checks,
                  fun: :from_bool,
                  args: [{:ctx, :result}],
                  result: :ok,
                  satisfied?: true
                }}

      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(
                 %Check{
                   module: Checks,
                   fun: :from_bool,
                   args: [{:ctx, :result}]
                 },
                 %{result: false}
               )

      assert expression == %Check{
               module: Checks,
               fun: :from_bool,
               args: [{:ctx, :result}],
               result: :error,
               satisfied?: false
             }
    end

    test "evaluates check that takes value from context keyword list as arg" do
      assert Spek.eval_tree(
               %Check{
                 module: Checks,
                 fun: :from_bool,
                 args: [{:ctx, :result}]
               },
               result: true
             ) ==
               {:ok,
                %Check{
                  module: Checks,
                  fun: :from_bool,
                  args: [{:ctx, :result}],
                  result: :ok,
                  satisfied?: true
                }}

      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(
                 %Check{
                   module: Checks,
                   fun: :from_bool,
                   args: [{:ctx, :result}]
                 },
                 result: false
               )

      assert expression == %Check{
               module: Checks,
               fun: :from_bool,
               args: [{:ctx, :result}],
               result: :error,
               satisfied?: false
             }
    end

    test "evaluates not with literal" do
      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(%Not{
                 expression: %Literal{satisfied?: true}
               })

      assert expression == %Not{
               expression: %Literal{satisfied?: true},
               satisfied?: false
             }

      assert Spek.eval_tree(%Not{
               expression: %Literal{satisfied?: false}
             }) ==
               {:ok,
                %Not{
                  expression: %Literal{satisfied?: false},
                  satisfied?: true
                }}
    end

    test "evaluates not with check" do
      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(
                 %Not{
                   expression: %Check{
                     module: Checks,
                     fun: :return_arg,
                     args: [{:ctx, :result}]
                   }
                 },
                 result: :ok
               )

      assert expression == %Not{
               expression: %Check{
                 satisfied?: true,
                 module: Checks,
                 fun: :return_arg,
                 args: [{:ctx, :result}],
                 result: :ok
               },
               satisfied?: false
             }

      assert Spek.eval_tree(
               %Not{
                 expression: %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [{:ctx, :result}]
                 }
               },
               result: {:error, :failed}
             ) ==
               {:ok,
                %Not{
                  expression: %Check{
                    satisfied?: false,
                    module: Checks,
                    fun: :return_arg,
                    args: [{:ctx, :result}],
                    result: {:error, :failed}
                  },
                  satisfied?: true
                }}
    end

    test "evaluates And without children" do
      assert Spek.eval_tree(%AllOf{children: []}) ==
               {:ok,
                %AllOf{
                  children: [],
                  satisfied?: true
                }}
    end

    test "evaluates And with one child" do
      assert Spek.eval_tree(%AllOf{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:ok]}
               ]
             }) ==
               {:ok,
                %AllOf{
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
                }}

      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(%AllOf{
                 children: [
                   %Check{module: Checks, fun: :return_arg, args: [:error]}
                 ]
               })

      assert expression == %AllOf{
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
      assert Spek.eval_tree(%AllOf{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:ok]},
                 %Check{module: Checks, fun: :return_arg, args: [true]}
               ]
             }) ==
               {:ok,
                %AllOf{
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
                }}

      # first check true, second check false
      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(%AllOf{
                 children: [
                   %Check{module: Checks, fun: :return_arg, args: [:ok]},
                   %Check{module: Checks, fun: :return_arg, args: [false]}
                 ]
               })

      assert expression == %AllOf{
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
      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(%AllOf{
                 children: [
                   %Check{module: Checks, fun: :return_arg, args: [:error]},
                   %Check{module: Checks, fun: :return_arg, args: [true]}
                 ]
               })

      assert expression == %AllOf{
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
      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(%AnyOf{children: []})

      assert expression == %AnyOf{
               children: [],
               satisfied?: false
             }
    end

    test "evaluates Or with one child" do
      assert Spek.eval_tree(%AnyOf{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:ok]}
               ]
             }) ==
               {:ok,
                %AnyOf{
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
                }}

      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(%AnyOf{
                 children: [
                   %Check{module: Checks, fun: :return_arg, args: [:error]}
                 ]
               })

      assert expression == %AnyOf{
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
      assert Spek.eval_tree(%AnyOf{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:ok]},
                 %Check{module: Checks, fun: :return_arg, args: [:error]}
               ]
             }) ==
               {:ok,
                %AnyOf{
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
                }}

      # first check false, second check true
      assert Spek.eval_tree(%AnyOf{
               children: [
                 %Check{module: Checks, fun: :return_arg, args: [:error]},
                 %Check{module: Checks, fun: :return_arg, args: [:ok]}
               ]
             }) ==
               {:ok,
                %AnyOf{
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
                }}

      # all checks false
      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(%AnyOf{
                 children: [
                   %Check{module: Checks, fun: :return_arg, args: [:error]},
                   %Check{module: Checks, fun: :return_arg, args: [false]}
                 ]
               })

      assert expression == %AnyOf{
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
