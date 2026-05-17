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

## Installation

Add `spek` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:spek, "~> 0.1.1"}
  ]
end
```

## Usage

## Expressions

### Check

Start by defining check functions (predicates) for your domain rules. These
functions can take any kind of input and must return either a boolean, `:ok`,
`:error`, `{:ok, term}`, or `{:error, term}`.

The example below defines two variants of the same check: The first one returns
a boolean, and the second one returns either `:ok` or an error tuple. We assume
that the value of the `subscribed` field is a boolean.

```elixir
defmodule MyApp.UserChecks do
  def user_subscribed?(%User{subscribed: subscribed}) do
    subscribed
  end

  def user_subscribed(%User{subscribed: true}), do: :ok
  def user_subscribed(%User{subscribed: false}), do: {:error, :not_subscribed}
end
```

These check functions can be referenced in a `Spek.Check` struct:

```elixir
%Spek.Check{module: MyApp.UserChecks, fun: :user_subscribed, args: [:ctx]}
```

Here, `args: [:ctx]` means that the context argument passed to the evaluation
functions is passed directly to the referenced `user_subscribed/1` function.
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

If we wanted to check that a user is not subscribed, we could write it like
this:

```elixir
%Spek.Not{
  expression: %Spek.Check{
    module: MyApp.UserChecks,
    fun: :user_subscribed,
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
      module: MyApp.UserChecks,
      fun: :user_active,
      args: [:ctx]
    },
    %Spek.Check{
      module: MyApp.UserChecks,
      fun: :user_subscribed,
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
      module: MyApp.NotificationChecks,
      fun: :security_notification,
      args: [{:ctx, :notification}]
    },
    %Spek.Check{
      module: MyApp.UserChecks,
      fun: :user_subscribed,
      args: [{:ctx, :user}]
    }
  ]
}
```

Note that we changed `[:ctx]` to `[{:ctx, :notification}]` and
`[{:ctx, :user}]`. This means instead of passing the whole evaluation context
to the check function, we can use a map or keyword list as context and pass
the value under the respective key to the check function.

The expression structs can be arbitrarily combined and nested.

```elixir
%AllOf{
  children: [
    %Spek.Check{
      module: MyApp.UserChecks,
      fun: :user_active,
      args: [{:ctx, :user}]
    },
    %Spek.Not{
      expression: %Spek.Check{
        module: MyApp.UserChecks,
        fun: :user_banned,
        args: [{:ctx, :user}]
      }
    },
    %AnyOf{
      children: [
        %Spek.Check{
          module: MyApp.NotificationChecks,
          fun: :security_notification,
          args: [{:ctx, :notification}]
        },
        %Spek.Check{
          module: MyApp.UserChecks,
          fun: :user_subscribed,
          args: [{:ctx, :user}]
        }
      ]
    }
  ]
}
```

## Builder functions

Writing out the structs like above is a bit tedious. Spek has builder functions
for all the structs. Let's rewrite the previous example, and let's also put it
in a module while we're at it.

```elixir
defmodule MyApp.Rules do
  def send_notification_rule do
    Spek.all_of([
      Spek.check(MyApp.UserChecks, :user_active, [{:ctx, :user}]),
      Spek.negate(
        Spek.check(MyApp.UserChecks, :user_banned, [{:ctx, :user}])
      ),
      Spek.any_of([
        Spek.check(MyApp.NotificationChecks, :security_notification, [{:ctx, :notification}]),
        Spek.check(MyApp.UserChecks, :user_subscribed, [{:ctx, :user}])
      ])
    ])
  end
end
```

That's better, but still a bit verbose. We can improve this by defining helper
functions for each check. Let's turn back to our user checks module. We don't
use the `{name}?` functions currently, but we probably need them elsewhere in
the application, so let's include them and keep everything together.

This is probably not how you would model active/banned/subscribed states in a
real application, but let's stick with it for the example.

```elixir
defmodule MyApp.UserChecks do
  def user_active?(%User{state: :active}), do: true
  def user_active?(%User{}), do: false

  def user_active(%User{state: :active}), do: :ok
  def user_active(%User{}), do: {:error, :user_inactive}

  def user_active_check(args \\ [:ctx]) do
    Spek.check(__MODULE__, :user_active, args)
  end

  def user_banned?(%User{banned: banned}), do: banned

  def user_banned(%User{banned: true}), do: :ok
  def user_banned(%User{banned: false}), do: {:error, :user_banned}

  def user_banned_check(args \\ [:ctx]) do
    Spek.check(__MODULE__, :user_active, args)
  end

  def user_subscribed?(%User{subscribed: subscribed}) do
    subscribed
  end

  def user_subscribed(%User{subscribed: true}), do: :ok
  def user_subscribed(%User{subscribed: false}), do: {:error, :not_subscribed}

  def user_subscribed_check(args \\ [:ctx]) do
    Spek.check(__MODULE__, :user_subscribed, args)
  end
end
```

Note that we default the check's `args` to `[:ctx]`, but allow the user to
override them.

Assuming that we set up our `NotificationChecks` module in the same way, we can
now change our rule definition to:

```elixir
defmodule MyApp.Rules do
  alias MyApp
  alias MyApp.UserChecks

  def send_notification_rule do
    Spek.all_of([
      UserChecks.user_active_check([{:ctx, :user}]),
      Spek.negate(
        UserChecks.user_banned_check([{:ctx, :user}])
      ),
      Spek.any_of([
        NotificationChecks.security_notification([{:ctx, :notification}]),
        UserChecks.user_subscribed([{:ctx, :user}])
      ])
    ])
  end
end
```

If we were to define a rule that only acts on a single object, we can rely on
the default `args`.

```elixir
Spek.all_of([
  UserChecks.user_active_check(),
  Spek.negate(
    UserChecks.user_banned_check()
  )
])
```

## Check macros

If we want to make our `UserChecks` module less verbose, we can optionally use
one of two macros.

The `Spek.Macros.build_check/2` macro defines a function that returns a check
that references a function in the current module.

Instead of:

```elixir
defmodule MyApp.UserChecks do
  def user_active(%User{state: :active}), do: :ok
  def user_active(%User{}), do: {:error, :user_inactive}

  def user_active_check(args \\ [:ctx]) do
    Spek.check(__MODULE__, :user_active, args)
  end
end
```

You can write:

```elixir
defmodule MyApp.UserChecks do
  import Spek.Macros

  def user_active(%User{state: :active}), do: :ok
  def user_active(%User{}), do: {:error, :user_inactive}

  build_check(:user_active)

  # or if you need different default args:
  # build_check(:user_active, [{:ctx, :user}])
end
```

If you want to go one step further, you can use `Spek.Macros.defcheck/2` to
define a check once and compile it for different use cases. We defined three
functions for the same predicate above: `user_active?/1`, `user_active/1`, and
`user_active_check/1`.

```elixir
defmodule MyApp.UserChecks do
  def user_active?(%User{state: :active}), do: true
  def user_active?(%User{}), do: false

  def user_active(%User{state: :active}), do: :ok
  def user_active(%User{}), do: {:error, :user_inactive}

  def user_active_check(args \\ [:ctx]) do
    Spek.check(__MODULE__, :user_active, args)
  end
end
```

You can replace all of that with:

```elixir
defmodule MyApp.UserChecks do
  import Spek.Macros

  defcheck user_active(%User{state: state}, reason: :user_inactive) do
    state == :active
  end
end
```

The only requirement for the do-block is that it evaluates to a boolean.

So far, all our check functions use a single argument, but there is no
limitation to the number of arguments. For example, if you wanted to define a
check that ensures that a user belongs to a certain organization, you could do
it like this:

```elixir
defmodule MyApp.UserChecks do
  import Spek.Macros

  defcheck member_of_organization(user, organization,
             args: [{:ctx, :user], {:ctx, :organization}],
             reason: :not_member_of_organization
           ) do
    user.organization_id == organization.id
  end
end
```

You can use it like this:

```elixir
user_a = %User{organization_id: 1}
user_b = %User{organization_id: 2}
organization = %Organization{id: 1}

member_of_organization?(user_a, organization) # => true
member_of_organization?(user_b, organization) # => false

member_of_organization(user_a, organization) # => :ok
member_of_organization(user_b, organization) # => {:error, :not_member_of_organization}

Spek.all_of([
  user_active([{:ctx, :user}]),
  member_of_organization_check()
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
def some_fun(%User{} = user) do
  UserChecks
  |> Spek.check(:user_active, [user])
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
defmodule MyApp.UserChecks do
  def user_subscribed(%User{subscribed: true}), do: :ok
  def user_subscribed(%User{subscribed: false}), do: {:error, :not_subscribed}i
end
```

And we build an expression from a single check that passes the whole context:

```elixir
def send_notification_rule do
  Spek.check(MyApp.UserChecks, :user_subscribed, [:ctx])
end
```

Then we build a function that does something only if the user is subscribed:

```elixir
def send_notification(%User{} = user, %Notification{} = notification) do
  with :ok <- Spek.eval(send_notification_rule(), user) do
    # ...
  end
end
```

If we have a more complex rule that combines checks that accept different kinds
of data, we can pass a map or keyword list as context, and use the tuple syntax
in the check definition.

```elixir
def complex_rule do
  Spek.all_of([
    Spek.check(MyApp.UserChecks, :user_subscribed, [{:ctx, :user}]),
    Spek.check(MyApp.NotificationChecks, :other_check, [{:ctx, :notification}]),
  ])
end

def do_something(%User{} = user, %Notification{} = notification) do
  with :ok <-
         Spek.eval(complex_rule(), user: user, notification: notification) do
    # ...
  end
end
```

There are several evaluation function with different return values. Except for
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
defmodule MyApp.Rules do
  import Spek

  alias MyApp.Checks

  def enterprise_export do
    all_of([
      check(Checks, :account_active),
      check(Checks, :user_has_export_permission),
      check(Checks, :two_factor_enabled)
    ])
  end

  def admin_override do
    all_of([
      check(Checks, :account_active),
      check(Checks, :user_is_admin)
    ])
  end

  def export_customer_data do
    any_of([
      all_of([
        enterprise_export(),
        check(Checks, :gdpr_training_completed)
      ]),
      all_of([
        admin_override(),
        check(Checks, :gdpr_training_completed)
      ])
    ])
  end
end
```

The module defines two simple rules, `enterprise_export` and `admin_override`,
and an additional third rule that combines both of them and adds additional
checks. The return value of the `export_customer_data` function is:

```elixir
# MyApp.Rules.export_customer_data()

%Spek.AnyOf{
  children: [
    %Spek.AllOf{
      children: [
        %Spek.AllOf{
          children: [
            %Spek.Check{
              module: MyApp.Checks,
              fun: :account_active,
              args: [:ctx],
            },
            %Spek.Check{
              module: MyApp.Checks,
              fun: :user_has_export_permission,
              args: [:ctx],
            },
            %Spek.Check{
              module: MyApp.Checks,
              fun: :two_factor_enabled,
              args: [:ctx],
            }
          ]
        },
        %Spek.Check{
          module: MyApp.Checks,
          fun: :gdpr_training_completed,
          args: [:ctx],
        }
      ]
    },
    %Spek.AllOf{
      children: [
        %Spek.AllOf{
          children: [
            %Spek.Check{
              module: MyApp.Checks,
              fun: :account_active,
              args: [:ctx],
            },
            %Spek.Check{
              module: MyApp.Checks,
              fun: :user_is_admin,
              args: [:ctx],
            }
          ]
        },
        %Spek.Check{
          module: MyApp.Checks,
          fun: :gdpr_training_completed,
          args: [:ctx],
        }
      ]
    }
  ]
}
```

Note that both the `account_active?` check and the `gdpr_training_completed?`
check appear in multiple branches. The `optimize` function will factor out
these common checks.

```elixir
# MyApp.Rules.export_customer_data() |> Spek.optimize()

%Spek.AllOf{
  children: [
    %Spek.Check{
      module: MyApp.Checks,
      fun: :gdpr_training_completed,
      args: [:ctx],
    },
    %Spek.AllOf{
      children: [
        %Spek.Check{
          module: MyApp.Checks,
          fun: :account_active,
          args: [:ctx],
        },
        %Spek.AnyOf{
          children: [
            %Spek.AllOf{
              children: [
                %Spek.Check{
                  module: MyApp.Checks,
                  fun: :user_has_export_permission,
                  args: [:ctx],
                },
                %Spek.Check{
                  module: MyApp.Checks,
                  fun: :two_factor_enabled,
                  args: [:ctx],
                }
              ]
            },
            %Spek.Check{
              module: MyApp.Checks,
              fun: :user_is_admin,
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
defmodule MyApp.Rules do
  import Spek

  alias MyApp.Checks

  @enterprise_export all_of([
                       check(Checks, :account_active),
                       check(Checks, :user_has_export_permission),
                       check(Checks, :two_factor_enabled)
                     ])

  @admin_override all_of([
                    check(Checks, :account_active),
                    check(Checks, :user_is_admin)
                  ])

  @export_customer_data any_of([
                          all_of([
                            @enterprise_export,
                            check(Checks, :gdpr_training_completed)
                          ]),
                          all_of([
                            @admin_override,
                            check(Checks, :gdpr_training_completed)
                          ])
                        ])

  @export_customer_data optimize(@export_customer_data)

  def enterprise_export, do: @enterprise_export
  def admin_override, do: @admin_override
  def export_customer_data, do: @export_customer_data
end
```

Compile-time optimization can also be useful if a rule depends on a
compile-time flag. In the following example, a Literal is created using a
value known at compile time:

```elixir
defmodule MyApp.Rules do
  import Spek

  alias MyApp.Checks

  @feature_enabled Application.compile_env(:spek, :feature_enabled, true)

  @enterprise_export all_of([
                       check(Checks, :account_active),
                       check(Checks, :user_has_export_permission),
                       literal(@feature_enabled)
                     ])
  @enterprise_export optimize(@enterprise_export)

  def enterprise_export, do: @enterprise_export
end
```

If the feature is enabled, the literal is removed from the expression:

```elixir
%Spek.AllOf{
  children: [
    %Spek.Check{module: MyApp.Checks, fun: :account_active, args: [:ctx]},
    %Spek.Check{module: MyApp.Checks, fun: :user_has_export_permission, args: [:ctx]}
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

The evaluation and optimization engine is based on the one introduced in
[LetMe](https://github.com/woylie/let_me) 2.0.0. If you need to evaluate rules
in the context of authorization policies, you may find LetMe's macro DSL
useful.
