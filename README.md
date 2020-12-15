# EctoHooks

In the past, [`Ecto`](https://github.com/elixir-ecto/ecto) provided automatic
[callbacks](https://hexdocs.pm/ecto/1.0.5/Ecto.Model.Callbacks.html) which could
be implemented to run before or after certain database operations using the
[`Ecto.Model`](https://hexdocs.pm/ecto/1.0.5/Ecto.Model.html) macro
(rather than the modern variant: `Ecto.Changeset`).

This library provides an a module you can `use` in your application's `MyApp.Repo`
module: `EctoHooks`. Upon invokation, any successful database
`Ecto.Repo` callbacks will trigger any hooks you've defined in a corresponding
`Ecto.Schema` module:

```elixir
def MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  use EctoHooks
end

def MyApp.User do
  use Ecto.Changeset

  schema "users" do
    field :first_name, :string
    field :last_name, :string

    field :full_name, :string, virtual: true
  end

  def after_get(%__MODULE__{first_name: first_name, last_name: last_name} = user) do
    %__MODULE__{user | full_name: first_name <> " " <> last_name}
  end
end
```

Alternatively, one can opt to use a more transparent API for initializing
`EctoHooks`:

```elixir
def MyApp.Repo do
  use EctoHooks.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres
end
```

The hooking functionality provided by `EctoHooks` can be pretty useful for resolving
virtual fields, but can also prove useful for centralising some logging or telemetry
logic. Note that because any business logic is executed synchronously after the
hooked `Ecto.Repo` callback, one should avoid doing any blocking or potentially
terminating logic within hooks as weird or strange behaviour may occur.

At the time of writing, this library does not intend on implementing any hooks
for executing logic _before_ a database operation. The only hooks implemented
are those that are executed following an appropriate `Ecto.Repo` callback.

## Links

- [hex.pm package link](https://hex.pm/packages/ecto_hooks)
- [online documentation](https://hexdocs.pm/ecto_hooks/EctoHooks.Repo.html)

## Installation

You can install this dependency by adding the following to your application's
`mix.exs`:

```elixir
def deps do
  [
    {:ecto_hooks, "~> 0.1.0"}
  ]
end
```

## Usage

Simply add the following line to your application's corresponding `MyApp.Repo`
module:

```elixir
use Ecto.Repo.Hooks
```

Any time an `Ecto.Repo` callback successfully returns a struct defined in a
module that `use`-es `Ecto.Model`, any corresponding defined hooks are
executed.

All hooks are of arity one, and take only the struct defined in the module as an
argument. Hooks are expected to return an updated struct on success, any other
value is treated as an error.

A list of valid hooks is listed below:

- `after_get/1` which is executed following `Ecto.Repo.all/2`,
    `Ecto.Repo.get/3`, `Ecto.Repo.get!/3`, `Ecto.Repo.get_by/3`,
    `Ecto.Repo.get_by!/3`, `Ecto.Repo.one/2`, `Ecto.Repo.one!/2`.
- `after_insert/1` which is executed following `Ecto.Repo.insert/2`,
    `Ecto.Repo.insert!/2`, `Ecto.Repo.insert_or_update/2`,
    `Ecto.Repo.insert_or_update!/2`
- `after_update/1` which is executed following `Ecto.Repo.update/2`,
    `Ecto.Repo.update!/2`, `Ecto.Repo.insert_or_update/2`,
    `Ecto.Repo.insert_or_update!/2`
- `after_delete/1` which is executed following `Ecto.Repo.delete/2`,
    `Ecto.Repo.delete!/2`
