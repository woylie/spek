defmodule Spek.EvaluationErrorTest do
  use ExUnit.Case

  describe "put_results/1" do
    test "returns struct unchanged if it has no expression" do
      error = %Spek.EvaluationError{message: "Hello!"}
      assert Spek.EvaluationError.put_results(error) == error
    end
  end
end
