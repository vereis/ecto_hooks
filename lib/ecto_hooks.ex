defmodule EctoHooks do
  @moduledoc """
  Middleware for adding `before_*` and `after_*` callbacks to Ecto schemas.

  EctoHooks brings back the convenience of `Ecto.Model` callbacks (removed in Ecto 2.0)
  using the modern `EctoMiddleware` pipeline pattern. Perfect for centralizing virtual
  field logic, audit logging, data normalization, and other cross-cutting concerns.

  > **Built on EctoMiddleware:** EctoHooks is powered by [EctoMiddleware](https://hex.pm/packages/ecto_middleware),
  > which is included as a dependency. Installing `ecto_hooks` gives you everything you need!

  ## Quick Example

      defmodule MyApp.User do
        use Ecto.Schema

        schema "users" do
          field :first_name, :string
          field :last_name, :string
          field :email, :string
          field :full_name, :string, virtual: true
        end

        # c:EctoHooks.before_insert/1 - called before c:Ecto.Repo.insert/2
        def before_insert(changeset) do
          # Normalize email before saving
          case Ecto.Changeset.fetch_change(changeset, :email) do
            {:ok, email} ->
              Ecto.Changeset.put_change(changeset, :email, String.downcase(email))
            :error ->
              changeset
          end
        end

        # c:EctoHooks.after_get/2 - called after c:Ecto.Repo.get/3, c:Ecto.Repo.all/2, etc.
        def after_get(%__MODULE__{} = user, %EctoHooks.Delta{}) do
          # Populate virtual fields after fetching
          %{user | full_name: "\#{user.first_name} \#{user.last_name}"}
        end
      end

      defmodule MyApp.Repo do
        use Ecto.Repo, otp_app: :my_app
        use EctoMiddleware.Repo

        @impl EctoMiddleware.Repo
        def middleware(_action, _resource) do
          [EctoHooks]
        end
      end

      # Hooks run automatically!
      MyApp.Repo.get!(MyApp.User, 1)
      #=> %MyApp.User{first_name: "Alice", last_name: "Smith", full_name: "Alice Smith"}

  ## Setup

  Add `EctoHooks` to your Repo's middleware pipeline. EctoHooks includes `EctoMiddleware`
  as a dependency, so you can use it directly:

      defmodule MyApp.Repo do
        use Ecto.Repo, otp_app: :my_app
        use EctoMiddleware.Repo  # Comes with ecto_hooks!

        @impl EctoMiddleware.Repo
        def middleware(_action, _resource) do
          [EctoHooks]  # Add alongside other middleware if needed
        end
      end

  All hooks are **optional** - if you don't define a hook, it simply doesn't run.

  ## Available Hooks

  ### Before Hooks (arity 1)

  Transform data **before** it reaches the database:

  - `c:before_insert/1` - Called before `c:Ecto.Repo.insert/2`, `c:Ecto.Repo.insert!/2`, and `c:Ecto.Repo.insert_or_update/2` (for new records)
  - `c:before_update/1` - Called before `c:Ecto.Repo.update/2`, `c:Ecto.Repo.update!/2`, and `c:Ecto.Repo.insert_or_update/2` (for existing records)
  - `c:before_delete/1` - Called before `c:Ecto.Repo.delete/2`, `c:Ecto.Repo.delete!/2`

  Before hooks receive the changeset/struct and must return a changeset/struct:

      # c:before_insert/1 example
      def before_insert(changeset) do
        changeset
        |> normalize_email()
        |> set_defaults()
        |> add_timestamps()
      end

  ### After Hooks (arity 2)

  Process data **after** database operations:

  - `c:after_get/2` - Called after `c:Ecto.Repo.get/3`, `c:Ecto.Repo.get!/3`, `c:Ecto.Repo.get_by/3`, `c:Ecto.Repo.all/2`, `c:Ecto.Repo.one/2`, `c:Ecto.Repo.reload/2`, `c:Ecto.Repo.preload/3`, etc.
  - `c:after_insert/2` - Called after `c:Ecto.Repo.insert/2`, `c:Ecto.Repo.insert!/2`, and `c:Ecto.Repo.insert_or_update/2` (for new records)
  - `c:after_update/2` - Called after `c:Ecto.Repo.update/2`, `c:Ecto.Repo.update!/2`, and `c:Ecto.Repo.insert_or_update/2` (for existing records)
  - `c:after_delete/2` - Called after `c:Ecto.Repo.delete/2`, `c:Ecto.Repo.delete!/2`

  After hooks receive the struct and a `t:EctoHooks.Delta.t/0` with metadata:

      # c:after_get/2 example
      def after_get(%__MODULE__{} = user, %EctoHooks.Delta{} = delta) do
        # delta.repo_callback - Which repo function was called (:get, :all, etc.)
        # delta.hook - Which hook is executing (:after_get)
        # delta.source - The original queryable/changeset/struct

        %{user | full_name: "\#{user.first_name} \#{user.last_name}"}
      end

  ## Hook Execution Flow

  For write operations (insert/update/delete):

  1. Call `c:before_*` hook on changeset/struct
  2. Execute database operation
  3. Call `c:after_*` hook on result
  4. Return final result

  For read operations (get/all/one):

  1. Execute database query
  2. Call `c:after_get/2` on result(s)
  3. Return transformed result(s)

  Hooks are applied to **all matching records**. For example, `c:Ecto.Repo.all/2` will
  call `c:after_get/2` on every record in the result list.

  ## Controlling Execution

  ### Preventing Infinite Loops

  EctoHooks automatically prevents infinite loops by disabling hooks while executing a hook.
  If a hook calls another Repo operation, that operation won't trigger its own hooks:

      def after_insert(user, _delta) do
        # This update won't trigger c:before_update/1 or c:after_update/2 hooks
        Repo.update!(User.changeset(user, %{last_login: DateTime.utc_now()}))
        user
      end

  ### Manual Control

  You can manually disable/enable hooks for the current process:

      # Disable hooks
      EctoHooks.disable_hooks()
      Repo.insert!(user)  # Won't trigger hooks

      # Re-enable hooks
      EctoHooks.enable_hooks()

  Use `hooks_enabled?/0` and `in_hook?/0` to check current state:

      EctoHooks.hooks_enabled?()  #=> true
      EctoHooks.in_hook?()        #=> false

  ## Use Cases

  ### Virtual Fields

  Centralize virtual field logic instead of scattering it across your codebase with `c:after_get/2`:

      def after_get(user, _delta) do
        %{user | full_name: "\#{user.first_name} \#{user.last_name}"}
      end

  ### Audit Logging

  Use `c:after_update/2` to track changes:

      def after_update(user, delta) do
        AuditLog.log("user_updated", user.id, delta.source)
        user
      end

  ### Data Normalization

  Use `c:before_insert/1` to normalize data before saving:

      def before_insert(changeset) do
        changeset
        |> normalize_email()
        |> trim_whitespace()
        |> set_defaults()
      end

  ### Telemetry Events

  Use `c:after_insert/2` to emit events:

      def after_insert(user, _delta) do
        :telemetry.execute([:myapp, :user, :created], %{}, %{user_id: user.id})
        user
      end

  ## Considerations

  - Hooks run **synchronously** - expensive operations may slow down queries
  - Hooks run for **every operation** - keep them lightweight
  - Consider using background jobs for heavy processing
  - Be careful with Repo calls inside hooks (see "Preventing Infinite Loops")

  ## Migration from v1.x

  EctoHooks v2.0 simplifies setup by leveraging `EctoMiddleware.Repo` directly.

  ### What Changed

  **v1.x Setup:**

      defmodule MyApp.Repo do
        use EctoHooks.Repo,
          otp_app: :my_app,
          adapter: Ecto.Adapters.Postgres
      end

  **v2.0 Setup:**

      defmodule MyApp.Repo do
        use Ecto.Repo,
          otp_app: :my_app,
          adapter: Ecto.Adapters.Postgres

        use EctoMiddleware.Repo

        @impl EctoMiddleware.Repo
        def middleware(_action, _resource) do
          [EctoHooks]
        end
      end

  ### Migration Steps

  1. Replace `use EctoHooks.Repo` with `use Ecto.Repo`
  2. Add `use EctoMiddleware.Repo` (already included with `ecto_hooks`)
  3. Implement the `c:EctoMiddleware.Repo.middleware/2` callback returning `[EctoHooks]`

  ### What Stays the Same

  **All hook definitions remain unchanged!** Your existing `c:before_insert/1`, `c:before_update/1`,
  `c:before_delete/1`, `c:after_get/2`, `c:after_insert/2`, `c:after_update/2`, and `c:after_delete/2`
  hooks in schemas will continue to work without modification:

      # These work exactly the same in v2.0
      def before_insert(changeset), do: changeset
      def after_get(user, delta), do: user

  ### Benefits of v2.0

  - **Composability**: Add multiple middleware alongside `EctoHooks`
  - **Built on EctoMiddleware**: Leverage the full middleware ecosystem (included!)
  - **Flexibility**: Full control over middleware ordering
  - **Simplicity**: One less wrapper module to understand

  ### Example: Adding Other Middleware

  The new setup makes it easy to compose multiple middleware:

      def middleware(_action, _resource) do
        [
          MyApp.RateLimiter,
          MyApp.Telemetry,
          EctoHooks,
          MyApp.CacheInvalidation
        ]
      end

  ## Implementation Details

  EctoHooks is implemented as an `EctoMiddleware` middleware that:
  - Implements `c:EctoMiddleware.process_before/2` for before hooks
  - Implements `c:EctoMiddleware.process_after/2` for after hooks
  - Uses `EctoMiddleware.Utils` guards for operation detection
  - Handles all Ecto return types (`{:ok, value}`, lists, tuples, etc.)
  """

  use EctoMiddleware

  import EctoMiddleware.Utils,
    only: [is_insert: 2, is_update: 2, is_delete: 2, is_read: 2, is_preload: 2]

  alias EctoHooks.Delta
  alias EctoHooks.State

  @hooks [
    :before_delete,
    :before_insert,
    :before_update,
    :after_delete,
    :after_get,
    :after_insert,
    :after_update
  ]

  # HACK: I don't want to add any dependencies I don't need to this library, so
  # we're just hackily generating a struct via this literal. Otherwise we'll
  # need to bring in Ecto as a dep, or ignore Dialyzer warnings.
  @callback before_insert(queryable :: %{__struct__: Ecto.Queryable}) :: %{
              __struct__: Ecto.Queryable
            }
  @callback before_update(queryable :: %{__struct__: Ecto.Queryable}) :: %{
              __struct__: Ecto.Queryable
            }
  @callback before_delete(queryable :: %{__struct__: Ecto.Queryable}) :: %{
              __struct__: Ecto.Queryable
            }

  @callback after_get(schema_struct :: struct(), delta :: Delta.t()) :: struct()
  @callback after_insert(schema_struct :: struct(), delta :: Delta.t()) :: struct()
  @callback after_update(schema_struct :: struct(), delta :: Delta.t()) :: struct()
  @callback after_delete(schema_struct :: struct(), delta :: Delta.t()) :: struct()

  @optional_callbacks before_insert: 1,
                      before_update: 1,
                      before_delete: 1,
                      after_get: 2,
                      after_insert: 2,
                      after_update: 2,
                      after_delete: 2

  @doc false
  @impl EctoMiddleware
  def process_before(resource, resolution) when is_insert(resource, resolution.action) do
    {:cont, before_insert(resource, resolution.action)}
  end

  def process_before(resource, resolution) when is_update(resource, resolution.action) do
    {:cont, before_update(resource, resolution.action)}
  end

  def process_before(resource, resolution) when is_delete(resource, resolution.action) do
    {:cont, before_delete(resource, resolution.action)}
  end

  def process_before(resource, _resolution) do
    {:cont, resource}
  end

  @doc false
  @impl EctoMiddleware
  def process_after(result, resolution) when is_insert(resolution.entity, resolution.action) do
    {:cont,
     EctoMiddleware.Utils.apply(result, resolution, fn value ->
       after_insert(value, resolution.action, resolution.before_output)
     end)}
  end

  def process_after(result, resolution) when is_update(resolution.entity, resolution.action) do
    {:cont,
     EctoMiddleware.Utils.apply(result, resolution, fn value ->
       after_update(value, resolution.action, resolution.before_output)
     end)}
  end

  def process_after(result, resolution) when is_delete(resolution.entity, resolution.action) do
    {:cont,
     EctoMiddleware.Utils.apply(result, resolution, fn value ->
       after_delete(value, resolution.action, resolution.before_output)
     end)}
  end

  def process_after(resource, resolution) when is_preload(resource, resolution.action) do
    {:cont,
     case Enum.at(resolution.args, 1) do
       preloads when is_list(preloads) -> handle_preloads(resource, preloads)
       preload when is_atom(preload) -> handle_preloads(resource, [preload])
       _otherwise -> resource
     end}
  end

  def process_after(result, resolution) when is_read(result, resolution.action) do
    {:cont,
     EctoMiddleware.Utils.apply(result, resolution, fn value ->
       after_get(value, resolution.action, resolution.before_output)
     end)}
  end

  def process_after(result, _resolution) do
    {:cont, result}
  end

  @doc """
  Enables hooks for all future Repo operations in the current process.

  By default, hooks are enabled. You only need to call this if you've previously
  disabled hooks and want to re-enable them.

  ## Options

  - `:global` - When `true` (default), enables hooks globally for the process.
    When `false`, only enables hooks for the next operation (used internally).

  ## Examples

      # Disable hooks temporarily
      EctoHooks.disable_hooks()
      Repo.insert!(user)  # Won't trigger hooks

      # Re-enable hooks
      EctoHooks.enable_hooks()
      Repo.insert!(user)  # Will trigger hooks

  ## Internal Use

  EctoHooks uses `enable_hooks(global: false)` internally to re-enable hooks
  after executing a hook. This prevents infinite loops when hooks call Repo operations.
  """
  @spec enable_hooks(Keyword.t()) :: :ok
  defdelegate enable_hooks(opts \\ [global: true]), to: State

  @doc """
  Disables hooks for all future Repo operations in the current process.

  Useful when you need to perform Repo operations without triggering hooks,
  such as during bulk operations or setup/teardown in tests.

  ## Options

  - `:global` - When `true` (default), disables hooks globally for the process.
    When `false`, only disables hooks for the next operation (used internally).

  ## Examples

      # Disable hooks for bulk operations
      EctoHooks.disable_hooks()

      users
      |> Enum.each(&Repo.insert!/1)  # None will trigger hooks

      # Re-enable when done
      EctoHooks.enable_hooks()

      # Or use in a specific scope
      try do
        EctoHooks.disable_hooks()
        perform_bulk_operation()
      after
        EctoHooks.enable_hooks()
      end

  ## Internal Use

  EctoHooks uses `disable_hooks(global: false)` internally to prevent infinite
  loops when a hook calls another Repo operation.
  """
  @spec disable_hooks(Keyword.t()) :: :ok
  defdelegate disable_hooks(opts \\ [global: true]), to: State

  @doc """
  Returns `true` if hooks are enabled for the current process, `false` otherwise.

  Use this to check whether hooks will execute before performing operations.

  ## Examples

      EctoHooks.hooks_enabled?()
      #=> true

      EctoHooks.disable_hooks()
      EctoHooks.hooks_enabled?()
      #=> false

      EctoHooks.enable_hooks()
      EctoHooks.hooks_enabled?()
      #=> true

  ## Notes

  This reflects the *global* state. Even if `hooks_enabled?/0` returns `true`,
  hooks won't execute if you're already inside a hook (see `in_hook?/0`).
  """
  @spec hooks_enabled?() :: boolean()
  defdelegate hooks_enabled?, to: State

  @doc """
  Returns `true` if currently executing inside a hook, `false` otherwise.

  EctoHooks automatically disables hooks when executing a hook to prevent
  infinite loops. This function lets you check if you're in that context.

  ## Examples

      # In your application code
      EctoHooks.in_hook?()
      #=> false

      # Inside a hook that calls Repo
      def after_insert(user, _delta) do
        EctoHooks.in_hook?()
        #=> true

        # This won't trigger hooks
        Repo.update!(User.changeset(user, %{last_login: DateTime.utc_now()}))
        user
      end

  ## Implementation

  Internally, this checks if the hook ref count (see `hooks_ref_count/0`) is
  greater than zero.
  """
  @spec in_hook?() :: boolean()
  defdelegate in_hook?, to: State

  @doc """
  Returns the current hook nesting level (ref count) for the process.

  Each time a hook executes, the ref count increments. When the hook finishes,
  it decrements. This allows for nested hook detection, though in practice
  the nesting level is typically 0 or 1.

  ## Examples

      EctoHooks.hooks_ref_count()
      #=> 0

      # Inside a hook
      def after_insert(user, _delta) do
        EctoHooks.hooks_ref_count()
        #=> 1
        user
      end

  ## Use Cases

  This is a low-level introspection function. Most users should use
  `hooks_enabled?/0` or `in_hook?/0` instead.
  """
  @spec hooks_ref_count() :: non_neg_integer()
  defdelegate hooks_ref_count, to: State

  # ============================================
  # Hook Execution
  # ============================================

  for hook <- @hooks do
    @doc false
    def unquote(hook)(struct, caller_function, delta \\ nil)

    def unquote(hook)(struct, caller_function, delta) when is_struct(struct) do
      hook = unquote(hook)

      struct
      |> get_schema_module()
      |> execute_hook(hook, struct, delta && Delta.new!(caller_function, hook, delta))
    end

    def unquote(hook)(data, _delta, _caller_function) do
      data
    end
  end

  defp get_schema_module(struct) when is_struct(struct) do
    if struct.__struct__ == Ecto.Changeset && struct.data do
      struct.data.__struct__
    else
      struct.__struct__
    end
  end

  defp execute_hook(schema, hook, param_1, param_2) do
    if State.hooks_enabled?() do
      :ok = State.disable_hooks(global: false)
      :ok = State.acquire_hook()

      apply(schema, hook, [param_1 | (param_2 && [param_2]) || []])
    else
      param_1
    end
  rescue
    _e in UndefinedFunctionError ->
      param_1
  after
    :ok = State.enable_hooks(global: false)
    :ok = State.release_hook()
  end

  # ============================================
  # Preload Handling
  # ============================================

  defp handle_preloads(structs, preloads) when is_list(structs) do
    Enum.map(structs, &handle_preloads(&1, preloads))
  end

  defp handle_preloads(struct, preloads) do
    struct
    |> traverse_preloads(preloads)
    |> after_get(:preload, struct)
  end

  defp traverse_preloads(nil, _preloads), do: nil

  defp traverse_preloads(struct, preloads) when is_list(preloads) do
    Enum.reduce(preloads, struct, fn preload, acc -> traverse_preloads(acc, preload) end)
  end

  defp traverse_preloads(struct, {preload, nested_preloads}) do
    {_, updated_struct} =
      Map.get_and_update(struct, preload, fn v ->
        {v, handle_preloads(v, nested_preloads)}
      end)

    updated_struct
  end

  defp traverse_preloads(struct, preload) when is_atom(preload) do
    {_, updated_struct} =
      Map.get_and_update(struct, preload, fn v ->
        {v, handle_preloads(v, [])}
      end)

    updated_struct
  end

  defp traverse_preloads(queryable, _preload) do
    queryable
  end
end
