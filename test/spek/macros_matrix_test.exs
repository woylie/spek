defmodule Spek.MacrosMatrixTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Spek.Check
  alias Spek.Literal

  @arg_forms [
    %{id: "none", args: [], guard: nil, body: "1 == 1", call: []},
    %{id: "plain", args: ["a"], guard: nil, body: "a == a", call: [1]},
    %{
      id: "list_pattern",
      args: ["[h | _]"],
      guard: nil,
      body: "h == h",
      call: [[1, 2]]
    },
    %{
      id: "map_pattern",
      args: ["%{k: v}"],
      guard: nil,
      body: "v == v",
      call: [%{k: 1}]
    },
    %{
      id: "whole_binding",
      args: ["%{k: v} = m"],
      guard: nil,
      body: "v == v and is_map(m)",
      call: [%{k: 1}]
    },
    %{
      id: "guarded",
      args: ["a"],
      guard: "is_integer(a)",
      body: "a == a",
      call: [1]
    },
    %{id: "default", args: ["a \\\\ 1"], guard: nil, body: "a == a", call: []},
    %{
      id: "two",
      args: ["a", "b"],
      guard: nil,
      body: "a == b",
      call: [1, 1]
    },
    %{
      id: "two_with_default",
      args: ["a", "b \\\\ 2"],
      guard: nil,
      body: "a == b",
      call: [2]
    },
    %{
      id: "three",
      args: ["a", "b", "c"],
      guard: nil,
      body: "a == b and b == c",
      call: [1, 1, 1]
    }
  ]

  @opt_forms [
    %{id: "none", opts: [], supplies_args?: false},
    %{id: "reason", opts: ["reason: :nope"], supplies_args?: false},
    %{id: "args", opts: [:args], supplies_args?: true},
    %{
      id: "args_and_reason",
      opts: [:args, "reason: :nope"],
      supplies_args?: true
    }
  ]

  @literal_bodies [
    %{id: "true", body: "true", satisfied?: true, result: :ok},
    %{
      id: "false",
      body: "false",
      satisfied?: false,
      result: {:error, :failed}
    },
    %{id: "ok", body: ":ok", satisfied?: true, result: :ok},
    %{id: "error", body: ":error", satisfied?: false, result: :error},
    %{
      id: "ok_tuple",
      body: "{:ok, :v}",
      satisfied?: true,
      result: {:ok, :v}
    },
    %{
      id: "error_tuple",
      body: "{:error, :v}",
      satisfied?: false,
      result: {:error, :v}
    }
  ]

  @runtime_bodies [
    %{id: "true", body: "a == a", satisfied?: true, result: :ok},
    %{
      id: "false",
      body: "a != a",
      satisfied?: false,
      result: {:error, :failed}
    },
    %{
      id: "ok",
      body: "if a == a, do: :ok, else: :error",
      satisfied?: true,
      result: :ok
    },
    %{
      id: "error",
      body: "if a != a, do: :ok, else: :error",
      satisfied?: false,
      result: :error
    },
    %{
      id: "ok_tuple",
      body: "if a == a, do: {:ok, :v}, else: {:error, :v}",
      satisfied?: true,
      result: {:ok, :v}
    },
    %{
      id: "error_tuple",
      body: "if a != a, do: {:ok, :v}, else: {:error, :v}",
      satisfied?: false,
      result: {:error, :v}
    }
  ]

  describe "argument and option forms" do
    test "compile without warnings and behave as documented" do
      combinations =
        for arg <- @arg_forms,
            opt <- @opt_forms,
            opt.supplies_args? or min_arity(arg) <= 1 do
          name = "#{arg.id}_args_#{opt.id}_opts"
          {name, arg, opt}
        end

      definitions =
        for {name, arg, opt} <- combinations do
          definition(name, arg.args ++ options(opt, arg), arg.guard, arg.body)
        end

      assert combinations
             |> Enum.map(fn {_, arg, _} -> arg.id end)
             |> Enum.uniq()
             |> length() == length(@arg_forms)

      module = compile_without_warnings!("ArgumentForms", definitions)

      for {name, arg, _opt} <- combinations do
        assert apply(module, :"#{name}?", arg.call) == true, name
        assert apply(module, :"#{name}", arg.call) == :ok, name
        assert %Check{} = apply(module, :"#{name}_check", []), name
      end
    end
  end

  describe "do-block forms" do
    test "compile without warnings and behave as documented" do
      literals =
        for body <- @literal_bodies, args <- [[], ["device"]] do
          {"literal_#{body.id}_#{length(args)}_args", args, body}
        end

      runtimes =
        for body <- @runtime_bodies, do: {"runtime_#{body.id}", ["a"], body}

      definitions =
        for {name, args, body} <- literals ++ runtimes do
          definition(name, args, nil, body.body)
        end

      module = compile_without_warnings!("DoBlockForms", definitions)

      for {name, args, body} <- literals do
        call = List.duplicate(:ignored, length(args))
        satisfied? = body.satisfied?

        assert apply(module, :"#{name}?", call) == body.satisfied?, name
        assert apply(module, :"#{name}", call) == body.result, name

        assert %Literal{satisfied?: ^satisfied?} =
                 apply(module, :"#{name}_check", []),
               name
      end

      for {name, _args, body} <- runtimes do
        assert apply(module, :"#{name}?", [1]) == body.satisfied?, name
        assert apply(module, :"#{name}", [1]) == body.result, name
        assert %Check{} = apply(module, :"#{name}_check", []), name
      end
    end
  end

  defp min_arity(%{args: args}) do
    Enum.count(args, &(not String.contains?(&1, "\\\\")))
  end

  defp options(%{opts: opts}, arg) do
    Enum.map(opts, fn
      :args -> "args: #{check_args(arg)}"
      option -> option
    end)
  end

  defp check_args(%{args: args}) do
    args
    |> Enum.with_index()
    |> Enum.map_join(", ", fn {_, index} -> "{:ctx, :arg#{index}}" end)
    |> then(&"[#{&1}]")
  end

  defp definition(name, params, guard, body) do
    params = if params == [], do: "", else: "(#{Enum.join(params, ", ")})"
    guard = if guard, do: " when #{guard}", else: ""

    """
      defcheck #{name}#{params}#{guard} do
        #{body}
      end
    """
  end

  defp compile_without_warnings!(module_name, definitions) do
    source = """
    defmodule Spek.MacrosMatrixTest.#{module_name} do
      import Spek.Macros

    #{Enum.join(definitions, "\n")}
    end
    """

    warnings = capture_io(:stderr, fn -> Code.eval_string(source) end)

    assert warnings == "",
           "defcheck emitted warnings from generated code:\n\n#{warnings}"

    Module.concat(Spek.MacrosMatrixTest, module_name)
  end
end
