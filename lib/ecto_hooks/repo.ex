defmodule EctoHooks.Repo do
  @moduledoc """
  This module is intended to replace any usage of `use Ecto.Repo`. When this is done,
  any of the following `Ecto.Repo` callbacks will execute any defined `before_*`
  or `after_*` hooks in your Ecto schemas before returning.

  ## Setup and initialization

  Simply `use` this module wherever you would `use Ecto.Schema`. Any provided
  options are currently forwarded to `use Ecto.Repo`. In the future, EctoHooks
  may provide additional functionality based on given options.

  Example Usage:

  ```elixir
  defmodule MyApp.Repo do
    use EctoHooks.Repo,
      otp_app: :my_app,
      adapter: Ecto.Adapters.Postgres
  end

  def MyApp.User do
    use Ecto.Schema
    require Logger

    schema "users" do
      field :first_name, :string
      field :last_name, :string

      field :full_name, :string, virtual: true
    end

    def before_insert(changeset) do
      Logger.warning("inserted a new user...")
      changeset
    end

    def after_get(%__MODULE__{} = user, %EctoHooks.Delta{}) do
      %__MODULE__{user | full_name: user.first_name <> " " <> user.last_name}
    end
  end
  ```

  ## Usage

  ### After Hooks

  Once initialized, the following `Ecto.Repo` callbacks will trigger the listed
  `after_*` hooks.

  Executes `after_get/2` if defined in schema:
  - `all/2`
  - `get/3`
  - `get!/3`
  - `get_by/3`
  - `get_by!/3`
  - `one/2`
  - `one!/2`
  - `reload/2`
  - `reload!/2`
  - `preload/3`

  Executes `after_delete/2` if defined in schema:
  - `delete/2`
  - `delete!/2`

  Executes `after_insert/2` if defined in schema:
  - `insert/2`
  - `insert!/2`

  Executes `after_update/2` if defined in schema:
  - `update/2`
  - `update!/2`

  Executes `after_insert/2` or to `after_update/2` if defined in schema:
  - `insert_or_update/2`
  - `insert_or_update!/2`

  Please note that the result of an `after_*` hook is the result which is intended
  to be returned by any of the above `Ecto.Repo` callbacks. All `after_*` hooks are
  expected to abide by the following typespec:

  ```elixir
  @spec after_*(schema_struct :: MyApp.User.t(), delta :: EctoHooks.Delta.t()) :: MyApp.User.t()
  ```

  And any `Ecto.Repo` callback which expects to return `{:ok, result}` over `result`
  will do so automatically.

  Take care to not break expected `Ecto.Repo` callback semantics as bugs resulting
  from these can prove difficult to diagnose and track down. As a rule of thumb, you
  should always aim to return the same type of argument passed into your defined hooks.

  ### Before Hooks

  Once initialized, the following `Ecto.Repo` callbacks will trigger the listed
  `before_*` hooks.

  Executes `before_delete/1` if defined in schema:
  - `delete/2`
  - `delete!/2`

  Executes `before_insert/1` if defined in schema:
  - `insert/2`
  - `insert!/2`

  Executes `before_update/1` if defined in schema:
  - `update/2`
  - `update!/2`

  Executes `before_insert/1` or to `before_update/1` if defined in schema:
  - `insert_or_update/2`
  - `insert_or_update!/2`

  Please note that the result of an `before_*` hook is usually the `Ecto.Queryable`
  which is passed as the first parameter to any of the above `Ecto.Repo` callbacks.
  All `before_*` hooks are expected to abide by the following typespec:

  ```elixir
  @spec before_*(queryable :: Ecto.Queryable.t()) :: Ecto.Queryable.t()
  ```

  ### Considerations

  EctoHooks was initially designed to help with centralizing and de-duplicating
  logic to resolve virtual fields when working with Ecto schemas. However, since
  EctoHooks allows you to call arbitrary functions in response to `Ecto.Repo` callbacks,
  it can be used for much more.

  All defined hooks are also *executed synchronously*, immediately before or after
  calling your `Ecto.Repo` callback. To try and mitigate the potential for infinite
  loops caused by hooks triggering other hooks, by default, EctoHooks will only
  trigger a hook if a parent function in *the current process stacktrace* is not another
  hook.

  As a result, one should take *great care* when spawning processes which may result
  in calling `Ecto.Repo` callbacks, as there is currently no mitigation for infinite
  loops provided.

  If you wish to opt in, opt out, or introspect the state of these mitigations, please
  see the documentation for the following functions: `EctoHooks.enable_hooks/1`,
  `EctoHooks.disable_hooks/1`, `EctoHooks.hooks_enabled?/0` and `EctoHooks.in_hook?/0`.

  This is a very powerful tool, and admittedly quite hidden and hard to track down.
  Trying to avoid adding too much business logic in your EctoHooks is wise for both
  performance reasons (as hooks are executed on every request), and maintainability
  reasons.
  """

  @doc """
  Enables EctoHooks integration in your `Ecto.Repo` module when `use`-ed.
  """
  defmacro __using__(opts) do
    quote do
      use Ecto.Repo, unquote(opts)
      require unquote(__MODULE__), as: Self

      Self.override_repo_callbacks()
    end
  end

  @doc false
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro override_repo_callbacks do
    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote do
      @behaviour EctoMiddleware

      use EctoMiddleware

      def middleware(_action, _resource) do
        [EctoHooks.Middleware.Before, EctoMiddleware.Super, EctoHooks.Middleware.After]
      end
    end
  end
end
