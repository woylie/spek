# Spek

![CI](https://github.com/woylie/spek/workflows/CI/badge.svg) [![Hex](https://img.shields.io/hexpm/v/spek)](https://hex.pm/packages/spek) [![Coverage Status](https://coveralls.io/repos/github/woylie/spek/badge.svg)](https://coveralls.io/github/woylie/spek)

Spek is a boolean expression engine for Elixir.

It allows you to model, optimize, and evaluate rules using composable
expressions.

## Features

- Expression structs and builder functions for boolean logic: `AllOf`, `AnyOf`,
  `Not`, `Literal`, `Check`.
- Evaluation of boolean expressions with optional early stopping and optional
  evaluation tree output.
- Optimization of boolean expressions using boolean algebra:
  - Identity
  - Annihilation
  - Idempotence
  - Double negation
  - De Morgan transformations
  - Absorption
  - Factorization
  - Deduplication
  - Constant folding
- Macros for concisely defining reusable check functions.

## Use cases

- Complex domain rules with composable conditions
- Specification pattern implementations
- Workflow, pipeline, and feature gating conditions
- User-configurable decision systems
- Auditable decision logs with per-check results and success/failure reasons

## Installation

Add `spek` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:spek, "~> 0.2.0"}
  ]
end
```

## Expressions

### Check

Start by defining check functions (predicates) for your domain rules. These
functions can take any kind of input and must return either a boolean, `:ok`,
`:error`, `{:ok, term}`, or `{:error, term}`.

The example below defines two variants of the same check: The first one returns
a boolean, and the second one returns either `:ok` or an error tuple. We assume
that the value of the `footage_ingested` field is a boolean.

```elixir
defmodule ProductionChecks do
  def footage_ingested?(%Production{footage_ingested: ingested}) do
    ingested
  end

  def footage_ingested(%Production{footage_ingested: true}), do: :ok
  def footage_ingested(%Production{footage_ingested: false}), do: {:error, :ingestion_missing}
end
```

These check functions can be referenced in a `Spek.Check` struct:

```elixir
%Spek.Check{module: ProductionChecks, fun: :footage_ingested, args: [:ctx]}
```

Here, `args: [:ctx]` means that the context argument passed to the evaluation
functions is passed directly to the referenced `footage_ingested/1` function.
More on that later.

A `Spek.Check` struct is a complete expression, but it can be combined with
other expression structs to define complex rules.

### Literal

The `Spek.Literal` struct always evaluates to a constant value:

```elixir
%Spek.Literal{result: true, satisfied?: true}
```

A `Literal` struct can be useful to quickly enable/disable something during
development, or to enable/disable a feature at compile time.

The struct has two fields:

- `satisfied?` - a boolean expressing the final outcome
- `result` - the raw evaluation result

In fact, all of the expression structs have these two fields, but the `Literal`
struct is the only one where these values are set during definition. In all
other structs, the values of these two fields are set during evaluation.

It may seem odd to have both a `satisfied?` and a `result` field for a constant
value. However, the `result` field can be used to convey more information to
the caller.

```elixir
%Spek.Literal{result: {:error, :feature_disabled}, satisfied?: false}
```

### Not

If we wanted to check that the footage is not ingested, we could write it like
this:

```elixir
%Spek.Not{
  expression: %Spek.Check{
    module: ProductionChecks,
    fun: :footage_ingested,
    args: [:ctx]
  }
}
```

### AllOf

Use `Spek.AllOf` to combine checks that _all_ must evaluate to `true`.

```elixir
%AllOf{
  children: [
    %Spek.Check{
      module: ProductionChecks,
      fun: :edit_session_active,
      args: [:ctx]
    },
    %Spek.Check{
      module: ProductionChecks,
      fun: :footage_ingested,
      args: [:ctx]
    }
  ]
}
```

### AnyOf

Use `Spek.AnyOf` if one of the checks must evaluate to `true`.

```elixir
%AnyOf{
  children: [
    %Spek.Check{
      module: PipelineChecks,
      fun: :render_cache_warmed,
      args: [{:ctx, :pipeline_event}]
    },
    %Spek.Check{
      module: ProductionChecks,
      fun: :footage_ingested,
      args: [{:ctx, :production}]
    }
  ]
}
```

Note that we changed `[:ctx]` to `[{:ctx, :pipeline_event}]` and
`[{:ctx, :production}]`. This means instead of passing the whole evaluation
context to the check function, we can use a map or keyword list as context and
pass the value under the respective key to the check function.

The expression structs can be arbitrarily combined and nested.

```elixir
%AllOf{
  children: [
    %Spek.Check{
      module: ProductionChecks,
      fun: :edit_session_active,
      args: [{:ctx, :production}]
    },
    %Spek.Not{
      expression: %Spek.Check{
        module: ProductionChecks,
        fun: :source_material_corrupt,
        args: [{:ctx, :production}]
      }
    },
    %AnyOf{
      children: [
        %Spek.Check{
          module: PipelineChecks,
          fun: :render_cache_warmed,
          args: [{:ctx, :pipeline_event}]
        },
        %Spek.Check{
          module: ProductionChecks,
          fun: :footage_ingested,
          args: [{:ctx, :production}]
        }
      ]
    }
  ]
}
```

## Builder functions

Writing out the structs like above is a bit tedious. Spek has builder functions
for all structs. Let's rewrite the previous example, and let's also put it
in a module while we're at it.

```elixir
defmodule Rules do
  def final_cut_release_rule do
    Spek.all_of([
      Spek.check(ProductionChecks, :edit_session_active, [{:ctx, :production}]),
      Spek.negate(
        Spek.check(ProductionChecks, :source_material_corrupt, [{:ctx, :production}])
      ),
      Spek.any_of([
        Spek.check(PipelineChecks, :render_cache_warmed, [{:ctx, :pipeline_event}]),
        Spek.check(ProductionChecks, :footage_ingested, [{:ctx, :production}])
      ])
    ])
  end
end
```

That's better, but still a bit verbose. We can improve this by defining helper
functions for each check. Let's turn back to our production checks module. We
don't use the `{name}?` functions currently, but we probably need them elsewhere
in the application, so let's include them and keep everything together.

```elixir
defmodule ProductionChecks do
  def edit_session_active?(%Production{state: :active}), do: true
  def edit_session_active?(%Production{}), do: false

  def edit_session_active(%Production{state: :active}), do: :ok
  def edit_session_active(%Production{}), do: {:error, :edit_session_stalled}

  def edit_session_active_check(args \\ [:ctx]) do
    Spek.check(__MODULE__, :edit_session_active, args)
  end

  def source_material_corrupt?(%Production{source_material_corrupt: source_material_corrupt}), do: source_material_corrupt

  def source_material_corrupt(%Production{source_material_corrupt: true}), do: :ok
  def source_material_corrupt(%Production{source_material_corrupt: false}), do: {:error, :source_material_corrupt}

  def source_material_corrupt_check(args \\ [:ctx]) do
    Spek.check(__MODULE__, :source_material_corrupt, args)
  end

  def footage_ingested?(%Production{footage_ingested: footage_ingested}) do
    footage_ingested
  end

  def footage_ingested(%Production{footage_ingested: true}), do: :ok
  def footage_ingested(%Production{footage_ingested: false}), do: {:error, :ingestion_missing}

  def footage_ingested_check(args \\ [:ctx]) do
    Spek.check(__MODULE__, :footage_ingested, args)
  end
end
```

Note that we default the check's `args` to `[:ctx]`, but allow the production to
override them.

Assuming that we set up our `PipelineChecks` module in the same way, we can
now change our rule definition to:

```elixir
defmodule Rules do
  def final_cut_release_rule do
    Spek.all_of([
      ProductionChecks.edit_session_active_check([{:ctx, :production}]),
      Spek.negate(
        ProductionChecks.source_material_corrupt_check([{:ctx, :production}])
      ),
      Spek.any_of([
        PipelineChecks.render_cache_warmed([{:ctx, :pipeline_event}]),
        ProductionChecks.footage_ingested([{:ctx, :production}])
      ])
    ])
  end
end
```

If we were to define a rule that only acts on a single object, we can rely on
the default `args`.

```elixir
Spek.all_of([
  ProductionChecks.edit_session_active_check(),
  Spek.negate(
    ProductionChecks.source_material_corrupt_check()
  )
])
```

## Check macros

If we want to make our `ProductionChecks` module less verbose, we can optionally use
one of two macros.

The `Spek.Macros.build_check/2` macro defines a function that returns a check
that references a function in the current module.

Instead of:

```elixir
defmodule ProductionChecks do
  def edit_session_active(%Production{state: :active}), do: :ok
  def edit_session_active(%Production{}), do: {:error, :edit_session_stalled}

  def edit_session_active_check(args \\ [:ctx]) do
    Spek.check(__MODULE__, :edit_session_active, args)
  end
end
```

You can write:

```elixir
defmodule ProductionChecks do
  import Spek.Macros

  def edit_session_active(%Production{state: :active}), do: :ok
  def edit_session_active(%Production{}), do: {:error, :edit_session_stalled}

  build_check(:edit_session_active)

  # or if you need different default args:
  # build_check(:edit_session_active, [{:ctx, :production}])
end
```

If you want to go one step further, you can use `Spek.Macros.defcheck/2` to
define a check once and compile it for different use cases. We defined three
functions for the same predicate above: `edit_session_active?/1`, `edit_session_active/1`, and
`edit_session_active_check/1`.

```elixir
defmodule ProductionChecks do
  def edit_session_active?(%Production{state: :active}), do: true
  def edit_session_active?(%Production{}), do: false

  def edit_session_active(%Production{state: :active}), do: :ok
  def edit_session_active(%Production{}), do: {:error, :edit_session_stalled}

  def edit_session_active_check(args \\ [:ctx]) do
    Spek.check(__MODULE__, :edit_session_active, args)
  end
end
```

You can replace all of that with:

```elixir
defmodule ProductionChecks do
  import Spek.Macros

  defcheck edit_session_active(%Production{state: state},
             reason: :edit_session_stalled) do
    state == :active
  end
end
```

The only requirement for the do-block is that it evaluates to a boolean.

So far, all our check functions use a single argument, but there is no
limitation to the number of arguments. For example, if you wanted to define a
check that ensures that a production belongs to a certain shot list, you could
do it like this:

```elixir
defmodule ProductionChecks do
  import Spek.Macros

  defcheck shot_list_included(production, shot_list,
             args: [{:ctx, :production}, {:ctx, :shot_list}],
             reason: :missing_shot_list
           ) do
    production.shot_list_id == shot_list.id
  end
end
```

You can use it like this:

```elixir
production_a = %Production{shot_list_id: 1}
production_b = %Production{shot_list_id: 2}
shot_list = %ShotList{id: 1}

shot_list_included?(production_a, shot_list) # => true
shot_list_included?(production_b, shot_list) # => false

shot_list_included(production_a, shot_list) # => :ok
shot_list_included(production_b, shot_list) # => {:error, :missing_shot_list}

Spek.all_of([
  edit_session_active([{:ctx, :production}]),
  shot_list_included_check()
])
```

The advantage of the `defcheck` macro is that it makes your predicates easier
to read and understand. The disadvantage is that the implementation details of
the three generated functions are hidden. The macros are optional, use them at
your own discretion.

## Evaluation

Now that we know how to define check functions and complex rules, we can turn
to evaluation.

In the simplest case, we can evaluate rules that don't require any context. This
is the case with literals:

```elixir
rule = Spek.literal(true)
Spek.eval?(rule) # => true
```

And with checks that don't require any arguments:

```elixir
def sunday? do
  Date.day_of_week(Date.utc_today()) == 7
end

def some_fun do
  __MODULE__
  |> Spek.check(:sunday?, [])
  |> Spek.eval?()
end
```

You also don't need a context if you hardcode check arguments:

```elixir
def day_of_week(i) do
  Date.day_of_week(Date.utc_today()) == i
end

def some_fun do
  __MODULE__
  |> Spek.check(:day_of_week, [7])
  |> Spek.eval?()
end
```

Or if you pass arguments to a check directly at runtime:

```elixir
def some_fun(%Production{} = production) do
  ProductionChecks
  |> Spek.check(:edit_session_active, [production])
  |> Spek.eval?()
end
```

While hardcoding fixed check arguments is fine, passing dynamic values directly
to a check should be avoided. It is better to separate the rule definition and
pass runtime values via the evaluation context (the second argument of all
evaluation functions). This allows you to both optimize the expression at
runtime (see below), and to serialize/deserialize rules, e.g. in order to
implement a dynamic rule builder.

There are two special values that can be used in the check's `args`.

- `:ctx` - Is substituted with the whole context at evaluation time.
- `{:ctx, key}` - Is substituted with the value at the given key in the
  evaluation context. The context must be either a map or a keyword list in
  this case.

Let's see this in an example. We'll use this check module:

```elixir
defmodule ProductionChecks do
  def footage_ingested(%Production{footage_ingested: true}), do: :ok
  def footage_ingested(%Production{footage_ingested: false}), do: {:error, :ingestion_missing}
end
```

And we build an expression from a single check that passes the whole context:

```elixir
def final_cut_release_rule do
  Spek.check(ProductionChecks, :footage_ingested, [:ctx])
end
```

Then we build a function that releases the final cut only if the footage is
ingested:

```elixir
def release_final_cut(%Production{} = production, %PipelineEvent{} = pipeline_event) do
  with :ok <- Spek.eval(final_cut_release_rule(), production) do
    # ...
  end
end
```

If we have a more complex rule that combines checks that accept different kinds
of data, we can pass a map or keyword list as context, and use the tuple syntax
in the check definition.

```elixir
def publishable_rule do
  Spek.all_of([
    Spek.check(ProductionChecks, :footage_ingested, [{:ctx, :production}]),
    Spek.check(PipelineChecks, :render_cache_warmed, [{:ctx, :pipeline_event}]),
  ])
end

def publish_if_publishable(%Production{} = production, %PipelineEvent{} = pipeline_event) do
  with :ok <-
         Spek.eval(publishable_rule(), production: production, pipeline_event: pipeline_event) do
    # ...
  end
end
```

There are several evaluation functions with different return values. Except for
functions ending with `_all`, evaluation stops early as soon as a final outcome
can be determined.

Functions with `tree` in their name return the evaluated expression with all
`result` and `satisfied?` fields set. In the error case, the evaluated
expression is part of the `Spek.EvaluationError` struct.

| Function                | Return value                                                     | Stops early | Returns evaluated expression |
| ----------------------- | ---------------------------------------------------------------- | ----------- | ---------------------------- |
| `Spek.eval/2`           | `:ok \| {:error, Spek.EvaluationError.t()}`                      | yes         | no                           |
| `Spek.eval?/2`          | `boolean`                                                        | yes         | no                           |
| `Spek.eval!/2`          | `:ok` or raises `Spek.EvaluationError.t()`                       | yes         | no                           |
| `Spek.eval_tree/2`      | `{:ok, Spek.expression()} \| {:error, Spek.EvaluationError.t()}` | yes         | yes                          |
| `Spek.eval_tree!/2`     | `Spek.expression()` or raises `Spek.EvaluationError.t()`         | yes         | yes                          |
| `Spek.eval_tree_all/2`  | `{:ok, Spek.expression()} \| {:error, Spek.EvaluationError.t()}` | no          | yes                          |
| `Spek.eval_tree_all!/2` | `Spek.expression()` or raises `Spek.EvaluationError.t()`         | no          | yes                          |

## Optimization

If you reuse and combine multiple rules into larger expressions, you may end up
with redundant checks. `Spek.optimize/1` applies boolean algebra
transformations to simplify these expressions.

Consider the following example:

```elixir
defmodule Rules do
  import Spek

  def dailies_package_ready do
    all_of([
      check(Checks, :proxy_media_available),
      check(Checks, :color_grade_locked),
      check(Checks, :audio_mix_completed)
    ])
  end

  def director_approval_override do
    all_of([
      check(Checks, :proxy_media_available),
      check(Checks, :post_supervisor_approval)
    ])
  end

  def deliver_final_master do
    any_of([
      all_of([
        dailies_package_ready(),
        check(Checks, :legal_clearance_completed)
      ]),
      all_of([
        director_approval_override(),
        check(Checks, :legal_clearance_completed)
      ])
    ])
  end
end
```

The module defines two simple rules, `dailies_package_ready` and `director_approval_override`,
and an additional third rule that combines both of them and adds additional
checks. The return value of the `deliver_final_master` function is:

```elixir
# Rules.deliver_final_master()

%Spek.AnyOf{
  children: [
    %Spek.AllOf{
      children: [
        %Spek.AllOf{
          children: [
            %Spek.Check{
              module: Checks,
              fun: :proxy_media_available,
              args: [:ctx],
            },
            %Spek.Check{
              module: Checks,
              fun: :color_grade_locked,
              args: [:ctx],
            },
            %Spek.Check{
              module: Checks,
              fun: :audio_mix_completed,
              args: [:ctx],
            }
          ]
        },
        %Spek.Check{
          module: Checks,
          fun: :legal_clearance_completed,
          args: [:ctx],
        }
      ]
    },
    %Spek.AllOf{
      children: [
        %Spek.AllOf{
          children: [
            %Spek.Check{
              module: Checks,
              fun: :proxy_media_available,
              args: [:ctx],
            },
            %Spek.Check{
              module: Checks,
              fun: :post_supervisor_approval,
              args: [:ctx],
            }
          ]
        },
        %Spek.Check{
          module: Checks,
          fun: :legal_clearance_completed,
          args: [:ctx],
        }
      ]
    }
  ]
}
```

Note that both the `proxy_media_available?` check and the `legal_clearance_completed?`
check appear in multiple branches. The `optimize` function will factor out
these common checks.

```elixir
# Rules.deliver_final_master() |> Spek.optimize()

%Spek.AllOf{
  children: [
    %Spek.Check{
      module: Checks,
      fun: :legal_clearance_completed,
      args: [:ctx],
    },
    %Spek.AllOf{
      children: [
        %Spek.Check{
          module: Checks,
          fun: :proxy_media_available,
          args: [:ctx],
        },
        %Spek.AnyOf{
          children: [
            %Spek.AllOf{
              children: [
                %Spek.Check{
                  module: Checks,
                  fun: :color_grade_locked,
                  args: [:ctx],
                },
                %Spek.Check{
                  module: Checks,
                  fun: :audio_mix_completed,
                  args: [:ctx],
                }
              ]
            },
            %Spek.Check{
              module: Checks,
              fun: :post_supervisor_approval,
              args: [:ctx],
            }
          ]
        }
      ]
    }
  ]
}
```

If you want to avoid runtime overhead, you may opt to optimize the expressions
at compile time:

```elixir
defmodule Rules do
  import Spek

  @dailies_package_ready all_of([
                       check(Checks, :proxy_media_available),
                       check(Checks, :color_grade_locked),
                       check(Checks, :audio_mix_completed)
                     ])

  @director_approval_override all_of([
                    check(Checks, :proxy_media_available),
                    check(Checks, :post_supervisor_approval)
                  ])

  @deliver_final_master any_of([
                          all_of([
                            @dailies_package_ready,
                            check(Checks, :legal_clearance_completed)
                          ]),
                          all_of([
                            @director_approval_override,
                            check(Checks, :legal_clearance_completed)
                          ])
                        ])

  @deliver_final_master optimize(@deliver_final_master)

  def dailies_package_ready, do: @dailies_package_ready
  def director_approval_override, do: @director_approval_override
  def deliver_final_master, do: @deliver_final_master
end
```

Compile-time optimization can also be useful if a rule depends on a
compile-time flag. In the following example, a Literal is created using a
value known at compile time:

```elixir
defmodule Rules do
  import Spek

  @auto_render_enabled Application.compile_env(:spek, :auto_render_enabled, true)

  @dailies_package_ready all_of([
                       check(Checks, :proxy_media_available),
                       check(Checks, :color_grade_locked),
                       literal(@auto_render_enabled)
                     ])
  @dailies_package_ready optimize(@dailies_package_ready)

  def dailies_package_ready, do: @dailies_package_ready
end
```

If the feature is enabled, the literal is removed from the expression:

```elixir
%Spek.AllOf{
  children: [
    %Spek.Check{module: Checks, fun: :proxy_media_available, args: [:ctx]},
    %Spek.Check{module: Checks, fun: :color_grade_locked, args: [:ctx]}
  ]
}
```

If the feature is disabled, the expression is reduced to a single literal:

```elixir
%Spek.Literal{satisfied?: false, result: false}
```

For more information about the optimizations that are applied, refer to the
documentation of `Spek.optimize/1`.

## Related libraries

[LetMe](https://github.com/woylie/let_me) is an authorization DSL that uses
Spek.
