# EctoHooks

## Installation

Add `:ecto_hooks` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_hooks, "~> 1.0.1"}
  ]
end
```

## About

In the past, Ecto provided a series of automatic [callbacks](https://hexdocs.pm/ecto/1.0.5/Ecto.Model.Callbacks.html) which would automatically be executed in response to CRUD-ing data.

While these callbacks were removed alongside [Ecto.Model](https://hexdocs.pm/ecto/1.0.5/Ecto.Model.html) for various reasons, in some situations, they can still prove to be extremely useful for things such as centralizing the setting of virtual fields, or firing :telemetry events.

This library tries to experimentally bring back support for these "hooks" in a transparent and admittedly auto-_magical_ way. Here is a minimal example:

```elixir
# 1) Replace your app's Repo initialization with one of the two following options:

# * Just `use EctoHooks`. This won't work if you've overridden any Ecto.Repo functions yourself
def MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  use EctoHooks
end

# * Replace `use Ecto.Repo` with `use EctoHooks.Repo`. This should work no matter what
def MyApp.Repo do
  use EctoHooks.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres
end

# 2) Define some hooks in any Ecto.Schema module
def MyApp.User do
  use Ecto.Schema
  require Logger

  schema "users" do
    field :first_name, :string
    field :last_name, :string

    field :full_name, :string, virtual: true
  end

  def before_insert(%Ecto.Changeset{} = changeset) do
    Logger.info("inserting new user")
    changeset
  end

  def after_get(%__MODULE__{} = user, %EctoHooks.Delta{}) do
    %__MODULE__{user | full_name: user.first_name <> " " <> user.last_name}
  end
end
```

EctoHooks supports two classes of hook, `before_*` hooks and `after_*` hooks. All `before_*` hooks are arity-one and allow you to mutate, introspect, or change a given queryable before passing it onto Ecto.Repo; all `after_*` hooks are arity-two and allow you to mutate, introspect, or change the result of your hooked Ecto.Repo callback.

For `after_*` hooks, importantly, a `EctoHooks.Delta` struct is passed in as a second argument, which allows you to reflect on various pieces of metadata about the action which triggered the hook. This allows you to only run hooks if certain fields are changed, amongst other things. Please [see the documentations re: EctoHooks.Delta](https://hexdocs.pm/ecto_hooks/EctoHooks.Delta.html) for more information.

Likewise, for a list of supported hooks and their behaviours, please see the [latest docs](https://hexdocs.pm/ecto_hooks/EctoHooks.Repo.html).

## Links

- [hex.pm package link](https://hex.pm/packages/ecto_hooks)
- [online documentation](https://hexdocs.pm/ecto_hooks/EctoHooks.Repo.html)
