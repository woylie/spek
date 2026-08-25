import Config

max_runs =
  case System.get_env("STREAM_DATA_MAX_RUNS") do
    nil -> if System.get_env("CI"), do: 10_000, else: 100
    value -> String.to_integer(value)
  end

config :stream_data, max_runs: max_runs
