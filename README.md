<p align="center">
  <img src="https://github.com/user-attachments/assets/7117678e-0c5a-472c-8b29-0a18cabbc2d0" alt="EctoHooks" style="max-width: 100%; height: auto;" />
</p>

# EctoHooks

[![Hex Version](https://img.shields.io/hexpm/v/ecto_hooks.svg)](https://hex.pm/packages/ecto_hooks)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ecto_hooks/)
[![CI Status](https://github.com/vereis/ecto_hooks/workflows/CI/badge.svg)](https://github.com/vereis/ecto_hooks/actions)
[![Coverage Status](https://coveralls.io/repos/github/vereis/ecto_hooks/badge.svg?branch=main)](https://coveralls.io/github/vereis/ecto_hooks?branch=main)

> Add `before_*` and `after_*` callbacks to your Ecto schemas, similar to the old `Ecto.Model` callbacks.

## Installation

Add `:ecto_hooks` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_hooks, "~> 2.0"}
  ]
end
```

> **Note:** EctoHooks is built on top of [EctoMiddleware](https://hex.pm/packages/ecto_middleware) 
> and includes it as a dependency. Installing `ecto_hooks` gives you everything you need - no 
> additional dependencies required!

## Quick Start

### 1. Setup Your Repo

Add `EctoHooks` to your Repo's middleware pipeline. Since `EctoMiddleware` is included 
with `ecto_hooks`, you can use it directly:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  use EctoMiddleware.Repo  # Comes with ecto_hooks!

  @impl EctoMiddleware.Repo
  def middleware(_action, _resource) do
    [EctoHooks]
  end
end
```

### 2. Define Hooks in Your Schemas

```elixir
defmodule MyApp.User do
  use Ecto.Schema
  require Logger

  schema "users" do
    field :first_name, :string
    field :last_name, :string
    field :full_name, :string, virtual: true
  end

  def before_insert(changeset) do
    Logger.info("Inserting new user")
    changeset
  end

  def after_get(%__MODULE__{} = user, %EctoHooks.Delta{}) do
    %{user | full_name: "#{user.first_name} #{user.last_name}"}
  end
end
```

That's it! The hooks will be called automatically whenever you use your Repo.

## Available Hooks

### Before Hooks (arity 1)

Transform data **before** it reaches the database:

- `before_insert/1` - Called before `insert/2`, `insert!/2`, and `insert_or_update/2` (for new records)
- `before_update/1` - Called before `update/2`, `update!/2`, and `insert_or_update/2` (for existing records)
- `before_delete/1` - Called before `delete/2`, `delete!/2`

```elixir
def before_insert(changeset) do
  # Normalize email before saving
  case Ecto.Changeset.fetch_change(changeset, :email) do
    {:ok, email} -> Ecto.Changeset.put_change(changeset, :email, String.downcase(email))
    :error -> changeset
  end
end
```

### After Hooks (arity 2)

Process data **after** database operations:

- `after_get/2` - Called after `get/3`, `get!/3`, `all/2`, `one/2`, `reload/2`, `preload/3`, etc.
- `after_insert/2` - Called after `insert/2`, `insert!/2`, and `insert_or_update/2` (for new records)
- `after_update/2` - Called after `update/2`, `update!/2`, and `insert_or_update/2` (for existing records)
- `after_delete/2` - Called after `delete/2`, `delete!/2`

All after hooks receive a `%EctoHooks.Delta{}` struct with metadata about the operation:

```elixir
def after_get(%__MODULE__{} = user, %EctoHooks.Delta{} = delta) do
  # delta.repo_callback - Which repo function was called (:get, :all, etc.)
  # delta.hook - Which hook is executing (:after_get, etc.)
  # delta.source - The original queryable/changeset/struct
  
  %{user | full_name: "#{user.first_name} #{user.last_name}"}
end
```

## How It Works

EctoHooks is built on top of [EctoMiddleware](https://hex.pm/packages/ecto_middleware), which provides a middleware pipeline pattern for Ecto operations (similar to Plug or Absinthe middleware).

When you add `EctoHooks` to your middleware pipeline, it:
1. Intercepts Repo operations
2. Calls the appropriate `before_*` hook on your schema (if defined)
3. Executes the actual database operation
4. Calls the appropriate `after_*` hook on the result (if defined)
5. Returns the final result

All hooks are **optional** - if you don't define a hook, it simply doesn't run.

## Why Hooks?

### Centralize Virtual Field Logic

Instead of setting virtual fields in every controller/context function:

```elixir
# Without hooks - scattered across codebase
def get_user(id) do
  user = Repo.get!(User, id)
  %{user | full_name: "#{user.first_name} #{user.last_name}"}
end

def list_users do
  User
  |> Repo.all()
  |> Enum.map(fn user -> 
    %{user | full_name: "#{user.first_name} #{user.last_name}"}
  end)
end
```

With hooks, it happens automatically:

```elixir
# With hooks - defined once in the schema
def after_get(user, _delta) do
  %{user | full_name: "#{user.first_name} #{user.last_name}"}
end

# Now these just work
Repo.get!(User, id)  # full_name set automatically
Repo.all(User)       # full_name set for all users
```

### Audit Logging

```elixir
def after_insert(user, delta) do
  AuditLog.log("user_created", user.id, delta.source)
  user
end

def after_update(user, delta) do
  AuditLog.log("user_updated", user.id, delta.source)
  user
end
```

### Data Normalization

```elixir
def before_insert(changeset) do
  changeset
  |> normalize_email()
  |> trim_strings()
  |> set_defaults()
end
```

## Controlling Hook Execution

Sometimes you need to disable hooks (e.g., to prevent infinite loops or for bulk operations):

```elixir
# Disable hooks for current process
EctoHooks.disable_hooks()
Repo.insert!(user)  # Hooks won't run

# Re-enable hooks
EctoHooks.enable_hooks()

# Check if hooks are enabled
EctoHooks.hooks_enabled?()  #=> true

# Check if currently inside a hook
EctoHooks.in_hook?()  #=> false
```

**Note:** EctoHooks automatically prevents infinite loops by disabling hooks while executing a hook. This means if a hook calls another Repo operation, that operation won't trigger its own hooks.

## Migration from v1.x

EctoHooks v2.0 simplifies the setup significantly:

**Before (v1.x):**
```elixir
defmodule MyApp.Repo do
  use EctoHooks.Repo,  # or use EctoHooks
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres
end
```

**After (v2.0):**
```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  use EctoMiddleware.Repo

  @impl EctoMiddleware.Repo
  def middleware(_action, _resource) do
    [EctoHooks]  # Can add other middleware here too!
  end
end
```

Hook definitions in schemas remain unchanged - all your existing hooks will continue to work.

## Links

- [hex.pm package](https://hex.pm/packages/ecto_hooks)
- [Online documentation](https://hexdocs.pm/ecto_hooks)
- [EctoMiddleware](https://hex.pm/packages/ecto_middleware) - The middleware engine powering EctoHooks

## License

MIT License. See [LICENSE](LICENSE) for details.
