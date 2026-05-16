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

    test "evaluates AllOf without children" do
      assert Spek.eval?(%AllOf{children: []}) == true
    end

    test "evaluates AllOf with one child" do
      assert Spek.eval?(%AllOf{
               children: [%Literal{satisfied?: true, result: :ok}]
             }) == true

      assert Spek.eval?(%AllOf{
               children: [%Literal{satisfied?: false, result: :error}]
             }) == false
    end

    test "evaluates AllOf with two children" do
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

    test "evaluates AnyOf without children" do
      assert Spek.eval?(%AnyOf{children: []}) == false
    end

    test "evaluates AnyOf with one child" do
      assert Spek.eval?(%AnyOf{
               children: [%Literal{satisfied?: true}]
             }) == true

      assert Spek.eval?(%AnyOf{
               children: [%Literal{satisfied?: false}]
             }) == false
    end

    test "evaluates AnyOf with two children" do
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

    test "evaluates AllOf without children" do
      assert Spek.eval_tree(%AllOf{children: []}) ==
               {:ok,
                %AllOf{
                  children: [],
                  satisfied?: true
                }}
    end

    test "evaluates AllOf with one child" do
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

    test "evaluates AllOf with two children" do
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

    test "evaluates AnyOf without children" do
      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(%AnyOf{children: []})

      assert expression == %AnyOf{
               children: [],
               satisfied?: false
             }
    end

    test "evaluates AnyOf with one child" do
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

    test "evaluates AnyOf with two children" do
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

  describe "eval_tree_all/2" do
    test "does not stop early with AllOf" do
      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree_all(%AllOf{
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
                 },
                 %Check{
                   module: Checks,
                   fun: :return_arg,
                   args: [true],
                   result: true,
                   satisfied?: true
                 }
               ],
               satisfied?: false
             }
    end

    test "does not stop early with AnyOf" do
      assert Spek.eval_tree_all(%AnyOf{
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
                    },
                    %Check{
                      module: Checks,
                      fun: :return_arg,
                      args: [:error],
                      result: :error,
                      satisfied?: false
                    }
                  ],
                  satisfied?: true
                }}
    end
  end

  describe "optimize/1" do
    test "returns Literal unchanged" do
      literal = %Literal{satisfied?: true}
      assert Spek.optimize(literal) == literal
    end

    test "returns Check unchanged" do
      check = %Check{module: MyModule, fun: :role, args: []}
      assert Spek.optimize(check) == check
    end

    test "removes nested not" do
      assert Spek.optimize(%Not{
               expression: %Not{expression: %Check{fun: :two_factor}}
             }) == %Check{fun: :two_factor}
    end

    test "resolves not on literals" do
      assert Spek.optimize(%Not{expression: %Literal{satisfied?: true}}) ==
               %Literal{satisfied?: false}

      assert Spek.optimize(%Not{expression: %Literal{satisfied?: false}}) ==
               %Literal{satisfied?: true}
    end

    test "pushes down Not in AllOf" do
      assert Spek.optimize(%Not{
               expression: %AllOf{
                 children: [%Check{fun: :suspended}, %Check{fun: :unverified}]
               }
             }) ==
               %AnyOf{
                 children: [
                   %Not{expression: %Check{fun: :suspended}},
                   %Not{expression: %Check{fun: :unverified}}
                 ]
               }
    end

    test "pushes down Not in AnyOf" do
      assert Spek.optimize(%Not{
               expression: %AnyOf{
                 children: [%Check{fun: :suspended}, %Check{fun: :unverified}]
               }
             }) ==
               %AllOf{
                 children: [
                   %Not{expression: %Check{fun: :suspended}},
                   %Not{expression: %Check{fun: :unverified}}
                 ]
               }
    end

    test "converts AllOf without children to true Literal" do
      assert Spek.optimize(%AllOf{children: []}) == %Literal{satisfied?: true}
    end

    test "converts AnyOf without children to false Literal" do
      assert Spek.optimize(%AnyOf{children: []}) == %Literal{
               satisfied?: false
             }
    end

    test "unwraps AllOf with a single child" do
      check = %Check{fun: :role, args: []}
      assert Spek.optimize(%AllOf{children: [check]}) == check
    end

    test "applies optimization on unwrapped AllOf child and on result" do
      assert Spek.optimize(%AllOf{children: [%AnyOf{children: []}]}) ==
               %Literal{satisfied?: false}
    end

    test "unwraps anyOf with a single child" do
      check = %Check{fun: :role, args: []}
      assert Spek.optimize(%AnyOf{children: [check]}) == check
    end

    test "applies optimization on unwrapped AnyOf child and on result" do
      assert Spek.optimize(%AnyOf{children: [%AllOf{children: []}]}) ==
               %Literal{satisfied?: true}
    end

    test "deduplicates AllOf" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Check{fun: :role},
                 %Check{fun: :two_fa},
                 %Check{fun: :role}
               ]
             }) == %AllOf{
               children: [
                 %Check{fun: :role},
                 %Check{fun: :two_fa}
               ]
             }
    end

    test "does not deduplicate AllOf checks with different args" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Check{fun: :role, args: [:admin]},
                 %Check{fun: :role, args: [:clown]}
               ]
             }) == %AllOf{
               children: [
                 %Check{fun: :role, args: [:admin]},
                 %Check{fun: :role, args: [:clown]}
               ]
             }
    end

    test "optimizes after deduplicating AllOf" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Literal{satisfied?: true},
                 %Literal{satisfied?: true}
               ]
             }) == %Literal{satisfied?: true}
    end

    test "unwraps AllOf if one child remains after optimization" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Literal{satisfied?: true},
                 %Check{fun: :two_factor}
               ]
             }) == %Check{fun: :two_factor}
    end

    test "deduplicates AnyOf" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %Check{fun: :role},
                 %Check{fun: :two_fa},
                 %Check{fun: :role}
               ]
             }) == %AnyOf{
               children: [
                 %Check{fun: :role},
                 %Check{fun: :two_fa}
               ]
             }
    end

    test "does not deduplicate AnyOf checks with different args" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %Check{fun: :role, args: [:admin]},
                 %Check{fun: :role, args: [:editor]}
               ]
             }) == %AnyOf{
               children: [
                 %Check{fun: :role, args: [:admin]},
                 %Check{fun: :role, args: [:editor]}
               ]
             }
    end

    test "optimizes after deduplicating AnyOf" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %Literal{satisfied?: true},
                 %Literal{satisfied?: true}
               ]
             }) == %Literal{satisfied?: true}

      assert Spek.optimize(%AnyOf{
               children: [
                 %Literal{satisfied?: false},
                 %Literal{satisfied?: false}
               ]
             }) == %Literal{satisfied?: false}
    end

    test "unwraps AnyOf if one child remains after optimization" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %Literal{satisfied?: false},
                 %Check{fun: :two_factor}
               ]
             }) == %Check{fun: :two_factor}
    end

    test "converts AllOf with false literal to literal" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Check{fun: :role, args: [:admin]},
                 %Literal{satisfied?: false}
               ]
             }) == %Literal{satisfied?: false}
    end

    test "converts AnyOf with true literal to literal" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %Check{fun: :role, args: [:admin]},
                 %Literal{satisfied?: true}
               ]
             }) == %Literal{satisfied?: true}
    end

    test "removes true literal from AllOf" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Check{fun: :role, args: [:admin]},
                 %Check{fun: :two_fa},
                 %Literal{satisfied?: true}
               ]
             }) == %AllOf{
               children: [
                 %Check{fun: :role, args: [:admin]},
                 %Check{fun: :two_fa}
               ]
             }
    end

    test "removes false literal from AnyOf" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %Check{fun: :role, args: [:admin]},
                 %Check{fun: :two_fa},
                 %Literal{satisfied?: false}
               ]
             }) == %AnyOf{
               children: [
                 %Check{fun: :role, args: [:admin]},
                 %Check{fun: :two_fa}
               ]
             }
    end

    test "factorizes AnyOf and collapses single-child factorized branches" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{fun: :check1},
                     %Check{fun: :check2}
                   ]
                 },
                 %AllOf{
                   children: [
                     %Check{fun: :check3},
                     %Check{fun: :check1}
                   ]
                 },
                 %Check{fun: :check4}
               ]
             }) == %AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{fun: :check1},
                     %AnyOf{
                       children: [
                         %Check{fun: :check2},
                         %Check{fun: :check3}
                       ]
                     }
                   ]
                 },
                 %Check{fun: :check4}
               ]
             }
    end

    test "factorizes AnyOf" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{fun: :check1},
                     %Check{fun: :check2},
                     %Check{fun: :check3}
                   ]
                 },
                 %AllOf{
                   children: [
                     %Check{fun: :check4},
                     %Check{fun: :check1},
                     %Check{fun: :check5}
                   ]
                 }
               ]
             }) == %AllOf{
               children: [
                 %Check{fun: :check1},
                 %AnyOf{
                   children: [
                     %AllOf{
                       children: [
                         %Check{fun: :check2},
                         %Check{fun: :check3}
                       ]
                     },
                     %AllOf{
                       children: [
                         %Check{fun: :check4},
                         %Check{fun: :check5}
                       ]
                     }
                   ]
                 }
               ]
             }
    end

    test "factorizes AnyOf and folds single child left behind" do
      # (A and B) or A = A
      assert Spek.optimize(%AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{fun: :check1},
                     %Check{fun: :check2}
                   ]
                 },
                 %AllOf{
                   children: [
                     %Check{fun: :check1}
                   ]
                 }
               ]
             }) == %Check{fun: :check1}
    end

    test "does not factorize AnyOf with single AllOf child" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{fun: :check1},
                     %Check{fun: :check2}
                   ]
                 },
                 %Check{fun: :check3}
               ]
             }) == %AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{fun: :check1},
                     %Check{fun: :check2}
                   ]
                 },
                 %Check{fun: :check3}
               ]
             }
    end

    test "anyof(allof(A), allof(A)) = A" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{fun: :check1}
                   ]
                 },
                 %AllOf{
                   children: [
                     %Check{fun: :check1}
                   ]
                 }
               ]
             }) == %Check{fun: :check1}
    end

    test "factorizes AllOf and collapses single-child factorized branches" do
      assert Spek.optimize(%AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{fun: :check1},
                     %Check{fun: :check2}
                   ]
                 },
                 %AnyOf{
                   children: [
                     %Check{fun: :check3},
                     %Check{fun: :check1}
                   ]
                 },
                 %Check{fun: :check4}
               ]
             }) == %AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{fun: :check1},
                     %AllOf{
                       children: [
                         %Check{fun: :check2},
                         %Check{fun: :check3}
                       ]
                     }
                   ]
                 },
                 %Check{fun: :check4}
               ]
             }
    end

    test "factorizes AllOf" do
      assert Spek.optimize(%AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{fun: :check1},
                     %Check{fun: :check2},
                     %Check{fun: :check3}
                   ]
                 },
                 %AnyOf{
                   children: [
                     %Check{fun: :check4},
                     %Check{fun: :check1},
                     %Check{fun: :check5}
                   ]
                 }
               ]
             }) == %AnyOf{
               children: [
                 %Check{fun: :check1},
                 %AllOf{
                   children: [
                     %AnyOf{
                       children: [
                         %Check{fun: :check2},
                         %Check{fun: :check3}
                       ]
                     },
                     %AnyOf{
                       children: [
                         %Check{fun: :check4},
                         %Check{fun: :check5}
                       ]
                     }
                   ]
                 }
               ]
             }
    end

    test "factorizes AllOf and folds single child left behind" do
      # (A or B) and A = A
      assert Spek.optimize(%AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{fun: :check1},
                     %Check{fun: :check2}
                   ]
                 },
                 %AnyOf{
                   children: [
                     %Check{fun: :check1}
                   ]
                 }
               ]
             }) == %Check{fun: :check1}
    end

    test "does not factorize AllOf with single AnyOf child" do
      assert Spek.optimize(%AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{fun: :check1},
                     %Check{fun: :check2}
                   ]
                 },
                 %Check{fun: :check3}
               ]
             }) == %AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{fun: :check1},
                     %Check{fun: :check2}
                   ]
                 },
                 %Check{fun: :check3}
               ]
             }
    end

    test "allof(anyof(A), anyof(A)) = A" do
      assert Spek.optimize(%AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{fun: :check1}
                   ]
                 },
                 %AnyOf{
                   children: [
                     %Check{fun: :check1}
                   ]
                 }
               ]
             }) == %Check{fun: :check1}
    end

    test "A and anyof(B) = A and B" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Check{fun: :check1},
                 %AnyOf{children: [%Check{fun: :check2}]}
               ]
             }) == %AllOf{
               children: [%Check{fun: :check1}, %Check{fun: :check2}]
             }
    end

    test "allof(anyof(A)) = A" do
      assert Spek.optimize(%AllOf{
               children: [
                 %AnyOf{children: [%Check{fun: :check1}]}
               ]
             }) == %Check{fun: :check1}
    end

    # | Absorption (OR) | `A or (A and B) = A` |
    # test "(A and B) or A = A" do
    #   assert Spek.optimize(%AnyOf{
    #            children: [
    #              %AllOf{children: [%Check{fun: :check1}, %Check{fun: :check2}]},
    #              %Check{fun: :check1}
    #            ]
    #          }) == %Check{fun: :check1}
    # end

    # | Absorption (AND) | `A and (A or B) = A` |
    # test "(A or B) and A = A" do
    #   assert Spek.optimize(%AllOf{
    #            children: [
    #              %AnyOf{children: [%Check{fun: :check1}, %Check{fun: :check2}]},
    #              %Check{fun: :check1}
    #            ]
    #          }) == %Check{fun: :check1}
    # end
  end
end
