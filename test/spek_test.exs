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
      assert Spek.eval?(%Literal{satisfied?: true, result: true}) == true
      assert Spek.eval?(%Literal{satisfied?: false, result: false}) == false
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
                   %Literal{satisfied?: v1, result: v1},
                   %Literal{satisfied?: v2, result: v2}
                 ]
               }) == expected
      end
    end

    test "evaluates AnyOf without children" do
      assert Spek.eval?(%AnyOf{children: []}) == false
    end

    test "evaluates AnyOf with one child" do
      assert Spek.eval?(%AnyOf{
               children: [%Literal{satisfied?: true, result: true}]
             }) == true

      assert Spek.eval?(%AnyOf{
               children: [%Literal{satisfied?: false, result: false}]
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
                   %Literal{satisfied?: v1, result: v1},
                   %Literal{satisfied?: v2, result: v2}
                 ]
               }) == expected
      end
    end
  end

  describe "eval_tree/2" do
    test "evaluates literal" do
      assert Spek.eval_tree(%Literal{satisfied?: true, result: true}) ==
               {:ok, %Literal{satisfied?: true, result: true}}

      assert {:error, %EvaluationError{expression: expression}} =
               Spek.eval_tree(%Literal{satisfied?: false, result: false})

      assert expression ==
               %Literal{satisfied?: false, result: false}
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
                 expression: %Literal{satisfied?: true, result: true}
               })

      assert expression == %Not{
               expression: %Literal{satisfied?: true, result: true},
               satisfied?: false
             }

      assert Spek.eval_tree(%Not{
               expression: %Literal{satisfied?: false, result: false}
             }) ==
               {:ok,
                %Not{
                  expression: %Literal{satisfied?: false, result: false},
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
      literal = %Literal{satisfied?: true, result: true}
      assert Spek.optimize(literal) == literal
    end

    test "returns Check unchanged" do
      check = %Check{module: Checks, fun: :role, args: []}
      assert Spek.optimize(check) == check
    end

    test "removes nested not" do
      assert Spek.optimize(%Not{
               expression: %Not{
                 expression: %Check{
                   module: Checks,
                   fun: :two_factor,
                   args: []
                 }
               }
             }) == %Check{module: Checks, fun: :two_factor, args: []}
    end

    test "resolves not on literals" do
      assert Spek.optimize(%Not{
               expression: %Literal{satisfied?: true, result: true}
             }) ==
               %Literal{satisfied?: false, result: false}

      assert Spek.optimize(%Not{
               expression: %Literal{satisfied?: false, result: false}
             }) ==
               %Literal{satisfied?: true, result: true}
    end

    test "pushes down Not in AllOf" do
      assert Spek.optimize(%Not{
               expression: %AllOf{
                 children: [
                   %Check{module: Checks, fun: :suspended, args: []},
                   %Check{module: Checks, fun: :unverified, args: []}
                 ]
               }
             }) ==
               %AnyOf{
                 children: [
                   %Not{
                     expression: %Check{
                       module: Checks,
                       fun: :suspended,
                       args: []
                     }
                   },
                   %Not{
                     expression: %Check{
                       module: Checks,
                       fun: :unverified,
                       args: []
                     }
                   }
                 ]
               }
    end

    test "pushes down Not in AnyOf" do
      assert Spek.optimize(%Not{
               expression: %AnyOf{
                 children: [
                   %Check{module: Checks, fun: :suspended, args: []},
                   %Check{module: Checks, fun: :unverified, args: []}
                 ]
               }
             }) ==
               %AllOf{
                 children: [
                   %Not{
                     expression: %Check{
                       module: Checks,
                       fun: :suspended,
                       args: []
                     }
                   },
                   %Not{
                     expression: %Check{
                       module: Checks,
                       fun: :unverified,
                       args: []
                     }
                   }
                 ]
               }
    end

    test "converts AllOf without children to true Literal" do
      assert Spek.optimize(%AllOf{children: []}) == %Literal{
               satisfied?: true,
               result: true
             }
    end

    test "converts AnyOf without children to false Literal" do
      assert Spek.optimize(%AnyOf{children: []}) == %Literal{
               satisfied?: false,
               result: false
             }
    end

    test "unwraps AllOf with a single child" do
      check = %Check{module: Checks, fun: :role, args: []}
      assert Spek.optimize(%AllOf{children: [check]}) == check
    end

    test "applies optimization on unwrapped AllOf child and on result" do
      assert Spek.optimize(%AllOf{children: [%AnyOf{children: []}]}) ==
               %Literal{satisfied?: false, result: false}
    end

    test "unwraps anyOf with a single child" do
      check = %Check{module: Checks, fun: :role, args: []}
      assert Spek.optimize(%AnyOf{children: [check]}) == check
    end

    test "applies optimization on unwrapped AnyOf child and on result" do
      assert Spek.optimize(%AnyOf{children: [%AllOf{children: []}]}) ==
               %Literal{satisfied?: true, result: true}
    end

    test "deduplicates AllOf" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Check{module: Checks, fun: :role, args: []},
                 %Check{module: Checks, fun: :two_fa, args: []},
                 %Check{module: Checks, fun: :role, args: []}
               ]
             }) == %AllOf{
               children: [
                 %Check{module: Checks, fun: :role, args: []},
                 %Check{module: Checks, fun: :two_fa, args: []}
               ]
             }
    end

    test "does not deduplicate AllOf checks with different args" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Check{module: Checks, fun: :role, args: [:admin]},
                 %Check{module: Checks, fun: :role, args: [:clown]}
               ]
             }) == %AllOf{
               children: [
                 %Check{module: Checks, fun: :role, args: [:admin]},
                 %Check{module: Checks, fun: :role, args: [:clown]}
               ]
             }
    end

    test "optimizes after deduplicating AllOf" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Literal{satisfied?: true, result: true},
                 %Literal{satisfied?: true, result: true}
               ]
             }) == %Literal{satisfied?: true, result: true}
    end

    test "unwraps AllOf if one child remains after optimization" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Literal{satisfied?: true, result: true},
                 %Check{module: Checks, fun: :two_factor, args: []}
               ]
             }) == %Check{module: Checks, fun: :two_factor, args: []}
    end

    test "deduplicates AnyOf" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %Check{module: Checks, fun: :role, args: []},
                 %Check{module: Checks, fun: :two_fa, args: []},
                 %Check{module: Checks, fun: :role, args: []}
               ]
             }) == %AnyOf{
               children: [
                 %Check{module: Checks, fun: :role, args: []},
                 %Check{module: Checks, fun: :two_fa, args: []}
               ]
             }
    end

    test "does not deduplicate AnyOf checks with different args" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %Check{module: Checks, fun: :role, args: [:admin]},
                 %Check{module: Checks, fun: :role, args: [:editor]}
               ]
             }) == %AnyOf{
               children: [
                 %Check{module: Checks, fun: :role, args: [:admin]},
                 %Check{module: Checks, fun: :role, args: [:editor]}
               ]
             }
    end

    test "optimizes after deduplicating AnyOf" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %Literal{satisfied?: true, result: true},
                 %Literal{satisfied?: true, result: true}
               ]
             }) == %Literal{satisfied?: true, result: true}

      assert Spek.optimize(%AnyOf{
               children: [
                 %Literal{satisfied?: false, result: false},
                 %Literal{satisfied?: false, result: false}
               ]
             }) == %Literal{satisfied?: false, result: false}
    end

    test "unwraps AnyOf if one child remains after optimization" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %Literal{satisfied?: false, result: false},
                 %Check{module: Checks, fun: :two_factor, args: []}
               ]
             }) == %Check{module: Checks, fun: :two_factor, args: []}
    end

    test "converts AllOf with false literal to literal" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Check{module: Checks, fun: :role, args: [:admin]},
                 %Literal{satisfied?: false, result: false}
               ]
             }) == %Literal{satisfied?: false, result: false}
    end

    test "converts AnyOf with true literal to literal" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %Check{module: Checks, fun: :role, args: [:admin]},
                 %Literal{satisfied?: true, result: true}
               ]
             }) == %Literal{satisfied?: true, result: true}
    end

    test "removes true literal from AllOf" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Check{module: Checks, fun: :role, args: [:admin]},
                 %Check{module: Checks, fun: :two_fa, args: []},
                 %Literal{satisfied?: true, result: true}
               ]
             }) == %AllOf{
               children: [
                 %Check{module: Checks, fun: :role, args: [:admin]},
                 %Check{module: Checks, fun: :two_fa, args: []}
               ]
             }
    end

    test "removes false literal from AnyOf" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %Check{module: Checks, fun: :role, args: [:admin]},
                 %Check{module: Checks, fun: :two_fa, args: []},
                 %Literal{satisfied?: false, result: false}
               ]
             }) == %AnyOf{
               children: [
                 %Check{module: Checks, fun: :role, args: [:admin]},
                 %Check{module: Checks, fun: :two_fa, args: []}
               ]
             }
    end

    test "factorizes AnyOf and collapses single-child factorized branches" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []}
                   ]
                 },
                 %AllOf{
                   children: [
                     %Check{module: Checks, fun: :check3, args: []},
                     %Check{module: Checks, fun: :check1, args: []}
                   ]
                 },
                 %Check{module: Checks, fun: :check4, args: []}
               ]
             }) == %AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %AnyOf{
                       children: [
                         %Check{module: Checks, fun: :check2, args: []},
                         %Check{module: Checks, fun: :check3, args: []}
                       ]
                     }
                   ]
                 },
                 %Check{module: Checks, fun: :check4, args: []}
               ]
             }
    end

    test "factorizes AnyOf" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []},
                     %Check{module: Checks, fun: :check3, args: []}
                   ]
                 },
                 %AllOf{
                   children: [
                     %Check{module: Checks, fun: :check4, args: []},
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check5, args: []}
                   ]
                 }
               ]
             }) == %AllOf{
               children: [
                 %Check{module: Checks, fun: :check1, args: []},
                 %AnyOf{
                   children: [
                     %AllOf{
                       children: [
                         %Check{module: Checks, fun: :check2, args: []},
                         %Check{module: Checks, fun: :check3, args: []}
                       ]
                     },
                     %AllOf{
                       children: [
                         %Check{module: Checks, fun: :check4, args: []},
                         %Check{module: Checks, fun: :check5, args: []}
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
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []}
                   ]
                 },
                 %AllOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []}
                   ]
                 }
               ]
             }) == %Check{module: Checks, fun: :check1, args: []}
    end

    test "does not factorize AnyOf with single AllOf child" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []}
                   ]
                 },
                 %Check{module: Checks, fun: :check3, args: []}
               ]
             }) == %AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []}
                   ]
                 },
                 %Check{module: Checks, fun: :check3, args: []}
               ]
             }
    end

    test "anyof(allof(A), allof(A)) = A" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []}
                   ]
                 },
                 %AllOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []}
                   ]
                 }
               ]
             }) == %Check{module: Checks, fun: :check1, args: []}
    end

    test "factorizes AllOf and collapses single-child factorized branches" do
      assert Spek.optimize(%AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []}
                   ]
                 },
                 %AnyOf{
                   children: [
                     %Check{module: Checks, fun: :check3, args: []},
                     %Check{module: Checks, fun: :check1, args: []}
                   ]
                 },
                 %Check{module: Checks, fun: :check4, args: []}
               ]
             }) == %AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %AllOf{
                       children: [
                         %Check{module: Checks, fun: :check2, args: []},
                         %Check{module: Checks, fun: :check3, args: []}
                       ]
                     }
                   ]
                 },
                 %Check{module: Checks, fun: :check4, args: []}
               ]
             }
    end

    test "factorizes AllOf" do
      assert Spek.optimize(%AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []},
                     %Check{module: Checks, fun: :check3, args: []}
                   ]
                 },
                 %AnyOf{
                   children: [
                     %Check{module: Checks, fun: :check4, args: []},
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check5, args: []}
                   ]
                 }
               ]
             }) == %AnyOf{
               children: [
                 %Check{module: Checks, fun: :check1, args: []},
                 %AllOf{
                   children: [
                     %AnyOf{
                       children: [
                         %Check{module: Checks, fun: :check2, args: []},
                         %Check{module: Checks, fun: :check3, args: []}
                       ]
                     },
                     %AnyOf{
                       children: [
                         %Check{module: Checks, fun: :check4, args: []},
                         %Check{module: Checks, fun: :check5, args: []}
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
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []}
                   ]
                 },
                 %AnyOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []}
                   ]
                 }
               ]
             }) == %Check{module: Checks, fun: :check1, args: []}
    end

    test "does not factorize AllOf with single AnyOf child" do
      assert Spek.optimize(%AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []}
                   ]
                 },
                 %Check{module: Checks, fun: :check3, args: []}
               ]
             }) == %AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []}
                   ]
                 },
                 %Check{module: Checks, fun: :check3, args: []}
               ]
             }
    end

    test "allof(anyof(A), anyof(A)) = A" do
      assert Spek.optimize(%AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []}
                   ]
                 },
                 %AnyOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []}
                   ]
                 }
               ]
             }) == %Check{module: Checks, fun: :check1, args: []}
    end

    test "A and anyof(B) = A and B" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Check{module: Checks, fun: :check1, args: []},
                 %AnyOf{
                   children: [%Check{module: Checks, fun: :check2, args: []}]
                 }
               ]
             }) == %AllOf{
               children: [
                 %Check{module: Checks, fun: :check1, args: []},
                 %Check{module: Checks, fun: :check2, args: []}
               ]
             }
    end

    test "allof(anyof(A)) = A" do
      assert Spek.optimize(%AllOf{
               children: [
                 %AnyOf{
                   children: [%Check{module: Checks, fun: :check1, args: []}]
                 }
               ]
             }) == %Check{module: Checks, fun: :check1, args: []}
    end

    test "A or (A and B) = A" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %Check{module: Checks, fun: :check1, args: []},
                 %AllOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []}
                   ]
                 }
               ]
             }) == %Check{module: Checks, fun: :check1, args: []}
    end

    test "(A and B) or A = A" do
      assert Spek.optimize(%AnyOf{
               children: [
                 %AllOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []}
                   ]
                 },
                 %Check{module: Checks, fun: :check1, args: []}
               ]
             }) == %Check{module: Checks, fun: :check1, args: []}
    end

    test "(A or B) and A = A" do
      assert Spek.optimize(%AllOf{
               children: [
                 %AnyOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []}
                   ]
                 },
                 %Check{module: Checks, fun: :check1, args: []}
               ]
             }) == %Check{module: Checks, fun: :check1, args: []}
    end

    test "A and (A or B) = A" do
      assert Spek.optimize(%AllOf{
               children: [
                 %Check{module: Checks, fun: :check1, args: []},
                 %AnyOf{
                   children: [
                     %Check{module: Checks, fun: :check1, args: []},
                     %Check{module: Checks, fun: :check2, args: []}
                   ]
                 }
               ]
             }) == %Check{module: Checks, fun: :check1, args: []}
    end
  end

  describe "collect_results/1" do
    test "returns result of a literal" do
      test_cases = [
        {true, true, []},
        {:ok, true, []},
        {false, false, []},
        {:error, false, []},
        {{:ok, "good"}, true, ["good"]},
        {{:error, "bad"}, false, ["bad"]}
      ]

      for {result, satisfied?, expected} <- test_cases do
        assert Spek.collect_results(%Literal{
                 result: result,
                 satisfied?: satisfied?
               }) == expected
      end
    end

    test "returns result of a check" do
      test_cases = [
        {true, true, []},
        {:ok, true, []},
        {false, false, []},
        {:error, false, []},
        {{:ok, "good"}, true, ["good"]},
        {{:error, "bad"}, false, ["bad"]}
      ]

      for {result, satisfied?, expected} <- test_cases do
        assert Spek.collect_results(%Check{
                 module: Checks,
                 fun: :some_check,
                 args: [],
                 result: result,
                 satisfied?: satisfied?
               }) == expected
      end
    end

    test "handles Not" do
      assert Spek.collect_results(%Not{satisfied?: true}) == []
    end

    test "returns results of an AllOf" do
      assert Spek.collect_results(%AllOf{
               children: [
                 %Literal{result: false, satisfied?: false},
                 %Check{
                   module: Checks,
                   fun: :some_check,
                   args: [],
                   result: {:ok, "good"},
                   satisfied?: true
                 },
                 %Literal{result: {:error, "bad"}, satisfied?: false}
               ]
             }) == ["good", "bad"]
    end

    test "returns results of an AnyOf" do
      assert Spek.collect_results(%AnyOf{
               children: [
                 %Literal{result: false, satisfied?: false},
                 %Check{
                   module: Checks,
                   fun: :some_check,
                   args: [],
                   result: {:ok, "good"},
                   satisfied?: true
                 },
                 %Literal{result: {:error, "bad"}, satisfied?: false}
               ]
             }) == ["good", "bad"]
    end

    test "returns nested results" do
      assert Spek.collect_results(%AllOf{
               children: [
                 %Literal{result: false, satisfied?: false},
                 %AllOf{
                   children: [
                     %Check{
                       module: Checks,
                       fun: :some_check,
                       args: [],
                       result: {:ok, "good"},
                       satisfied?: true
                     },
                     %Literal{result: {:error, "bad"}, satisfied?: false}
                   ]
                 }
               ]
             }) == ["good", "bad"]
    end
  end

  describe "collect_results/2" do
    test "filters success results of literal" do
      test_cases = [
        {true, true, []},
        {:ok, true, []},
        {false, false, []},
        {:error, false, []},
        {{:ok, "good"}, true, ["good"]},
        {{:error, "bad"}, false, []}
      ]

      for {result, satisfied?, expected} <- test_cases do
        assert Spek.collect_results(
                 %Literal{
                   result: result,
                   satisfied?: satisfied?
                 },
                 :ok
               ) == expected
      end
    end

    test "filters error results of literal" do
      test_cases = [
        {true, true, []},
        {:ok, true, []},
        {false, false, []},
        {:error, false, []},
        {{:ok, "good"}, true, []},
        {{:error, "bad"}, false, ["bad"]}
      ]

      for {result, satisfied?, expected} <- test_cases do
        assert Spek.collect_results(
                 %Literal{
                   result: result,
                   satisfied?: satisfied?
                 },
                 :error
               ) == expected
      end
    end

    test "filters success results of a check" do
      test_cases = [
        {true, true, []},
        {:ok, true, []},
        {false, false, []},
        {:error, false, []},
        {{:ok, "good"}, true, ["good"]},
        {{:error, "bad"}, false, []}
      ]

      for {result, satisfied?, expected} <- test_cases do
        assert Spek.collect_results(
                 %Check{
                   module: Checks,
                   fun: :some_check,
                   args: [],
                   result: result,
                   satisfied?: satisfied?
                 },
                 :ok
               ) == expected
      end
    end

    test "filters error results of a check" do
      test_cases = [
        {true, true, []},
        {:ok, true, []},
        {false, false, []},
        {:error, false, []},
        {{:ok, "good"}, true, []},
        {{:error, "bad"}, false, ["bad"]}
      ]

      for {result, satisfied?, expected} <- test_cases do
        assert Spek.collect_results(
                 %Check{
                   module: Checks,
                   fun: :some_check,
                   args: [],
                   result: result,
                   satisfied?: satisfied?
                 },
                 :error
               ) == expected
      end
    end

    test "reverses filter within a Not" do
      test_cases = [
        # literal.result, literal.satisfied?, arg, expected
        {{:ok, "good"}, true, :ok, []},
        {{:ok, "good"}, true, :error, ["good"]},
        {{:error, "bad"}, false, :ok, ["bad"]},
        {{:error, "bad"}, false, :error, []}
      ]

      for {result, satisfied?, only, expected} <- test_cases do
        assert Spek.collect_results(
                 %Not{
                   satisfied?: not satisfied?,
                   expression: %Literal{result: result, satisfied?: satisfied?}
                 },
                 only
               ) == expected
      end
    end

    test "filters results of an AllOf" do
      expression =
        %AllOf{
          children: [
            %Literal{result: false, satisfied?: false},
            %Check{
              module: Checks,
              fun: :some_check,
              args: [],
              result: {:ok, "good"},
              satisfied?: true
            },
            %Literal{result: {:error, "bad"}, satisfied?: false}
          ]
        }

      assert Spek.collect_results(expression, :ok) == ["good"]
      assert Spek.collect_results(expression, :error) == ["bad"]
    end

    test "filters results of an AnyOf" do
      expression =
        %AnyOf{
          children: [
            %Literal{result: false, satisfied?: false},
            %Check{
              module: Checks,
              fun: :some_check,
              args: [],
              result: {:ok, "good"},
              satisfied?: true
            },
            %Literal{result: {:error, "bad"}, satisfied?: false}
          ]
        }

      assert Spek.collect_results(expression, :ok) == ["good"]
      assert Spek.collect_results(expression, :error) == ["bad"]
    end

    test "filters results of a nested expression" do
      expression =
        %AllOf{
          children: [
            %Literal{
              result: {:ok, "literal good"},
              satisfied?: true
            },
            %Check{
              module: Checks,
              fun: :some_check,
              args: [],
              result: {:error, "check bad"},
              satisfied?: false
            },
            %Not{
              satisfied?: true,
              expression: %AnyOf{
                children: [
                  %Literal{
                    result: {:ok, "nested literal good"},
                    satisfied?: true
                  },
                  %Check{
                    module: Checks,
                    fun: :some_check,
                    args: [],
                    result: {:error, "nested check bad"},
                    satisfied?: false
                  }
                ]
              }
            }
          ]
        }

      assert Spek.collect_results(expression, :ok) == [
               "literal good",
               "nested check bad"
             ]

      assert Spek.collect_results(expression, :error) == [
               "check bad",
               "nested literal good"
             ]
    end
  end
end
