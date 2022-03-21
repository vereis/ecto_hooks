defmodule EctoHooks do
  @moduledoc """
  When `use`-ed in a module that also `use`-es `Ecto.Repo`, augments the following
  `Ecto.Repo` callbacks to provide user definable hooks following successful
  execution.

  Hooks to `MyApp.EctoSchema.after_get/2`:
  - `all/2`
  - `get/3`
  - `get!/3`
  - `get_by/3`
  - `get_by!/3`
  - `one/2`
  - `one!/2`

  Hooks to `MyApp.EctoSchema.after_delete/2`:
  - `delete/2`
  - `delete!/2`

  Hooks to `MyApp.EctoSchema.after_insert/2`:
  - `insert/2`
  - `insert!/2`

  Hooks to `MyApp.EctoSchema.after_update/2`:
  - `update/2`
  - `update!/2`

  Hooks to `MyApp.EctoSchema.after_insert/2` or to `MyApp.Ecto.Schema.after_update/2`:
  - `insert_or_update/2`
  - `insert_or_update!/2`

  Hooks to `MyApp.EctoSchema.before_delete/1`:
  - `delete/2`
  - `delete!/2`

  Hooks to `MyApp.EctoSchema.before_insert/1`:
  - `insert/2`
  - `insert!/2`

  Hooks to `MyApp.EctoSchema.before_update/1`:
  - `update/2`
  - `update!/2`

  Hooks to `MyApp.EctoSchema.before_insert/1` or to `MyApp.Ecto.Schema.before_update/1`:
  - `insert_or_update/2`
  - `insert_or_update!/2`

  Please note that for all `after_*` hooks, the result of executing a `MyApp.Repo.*` callback
  is what ultimately gets returned from the hook, and thus you should aim to write logic
  that is transparent and does not break the expected semantics or behaviour of said
  callback.

  Also, all `after_*` hooks are provided with the changeset, query, or schema used for
  insertion as a second parameter, which in some cases can be helpful for intuiting
  the diff between the result before versus after running a repo operation.

  Any results wrapped within an `{:ok, _}` or `{:error, _}` are also returned re-wrapped
  as expected.

  For all `before_*` hooks, the result returned by hook is passed directly to the `MyApp.Repo.*`
  callback called and thus care must be made to be aware of any implicit changes to changesets
  prior to writing to the database.

  The hooking functionality provided by `EctoHooks` can be pretty useful for resolving
  virtual fields, but can also prove useful for centralising some logging or telemetry
  logic.

  All defined hooks are executed synchronously immediately before or after calling into
  your configured database. To prevent the potential for hooks to infinite loop before
  returning, by default, EctoHooks will not trigger more than once within a single
  Repo call. You can opt out of this via calling `EctoHooks.enable_hooks/0` in any
  of your defined hooks.

  This infinite loop protection only currently works within a given process. Take care
  when a defined hook may spawn other processes which may trigger database updates which
  themselves result in hooks being called.

  ## Example usage:
  ```elixir
  def MyApp.Repo do
    use Ecto.Repo,
      otp_app: :my_app,
      adapter: Ecto.Adapters.Postgres

    use EctoHooks
  end

  def MyApp.User do
    use Ecto.Changeset

    require Logger

    schema "users" do
      field :first_name, :string
      field :last_name, :string

      field :full_name, :string, virtual: true
    end

    def before_insert(changeset) do
      Logger.warning("updating a user...")
      changeset
    end

    def after_get(%__MODULE__{first_name: first_name, last_name: last_name} = user) do
      %__MODULE__{user | full_name: first_name <> " " <> last_name}
    end
  end
  ```
  """

  defmacro __using__(_opts) do
    quote do
      @hooks unquote(__MODULE__)

      defoverridable all: 2,
                     delete: 2,
                     delete!: 2,
                     get: 3,
                     get!: 3,
                     get_by: 3,
                     get_by!: 3,
                     insert: 2,
                     insert!: 2,
                     insert_or_update: 2,
                     insert_or_update!: 2,
                     one: 2,
                     one!: 2,
                     update: 2,
                     update!: 2

      def insert(changeset, opts) do
        changeset = @hooks.before_insert(changeset)

        with {:ok, result} <- super(changeset, opts) do
          {:ok, @hooks.after_insert(result, changeset)}
        end
      after
        @hooks.enable_hooks()
      end

      def insert!(changeset, opts) do
        changeset = @hooks.before_insert(changeset)

        changeset
        |> super(opts)
        |> @hooks.after_insert(changeset)
      after
        @hooks.enable_hooks()
      end

      def update(changeset, opts) do
        changeset = @hooks.before_update(changeset)

        with {:ok, result} <- super(changeset, opts) do
          {:ok, @hooks.after_update(result, changeset)}
        end
      after
        @hooks.enable_hooks()
      end

      def update!(changeset, opts) do
        changeset = @hooks.before_update(changeset)

        changeset
        |> super(opts)
        |> @hooks.after_update(changeset)
      after
        @hooks.enable_hooks()
      end

      def get(query, id, opts) do
        with %{__meta__: %Ecto.Schema.Metadata{}} = result <- super(query, id, opts) do
          @hooks.after_get(result, query)
        end
      after
        @hooks.enable_hooks()
      end

      def get!(query, id, opts) do
        query
        |> super(id, opts)
        |> @hooks.after_get(query)
      after
        @hooks.enable_hooks()
      end

      def get_by(query, clauses, opts) do
        with %{__meta__: %Ecto.Schema.Metadata{}} = result <- super(query, clauses, opts) do
          @hooks.after_get(result, query)
        end
      after
        @hooks.enable_hooks()
      end

      def get_by!(query, clauses, opts) do
        query
        |> super(clauses, opts)
        |> @hooks.after_get(query)
      after
        @hooks.enable_hooks()
      end

      def one(query, opts) do
        with %{__meta__: %Ecto.Schema.Metadata{}} = result <- super(query, opts) do
          @hooks.after_get(result, query)
        end
      after
        @hooks.enable_hooks()
      end

      def one!(query, opts) do
        query
        |> super(opts)
        |> @hooks.after_get(query)
      after
        @hooks.enable_hooks()
      end

      def all(query, opts) do
        query
        |> super(opts)
        |> Enum.map(&@hooks.after_get(&1, query))
      after
        @hooks.enable_hooks()
      end

      def delete(changeset_or_query, opts) do
        changeset_or_query = @hooks.before_delete(changeset_or_query)

        with {:ok, result} <- super(changeset_or_query, opts) do
          {:ok, @hooks.after_delete(result, changeset_or_query)}
        end
      after
        @hooks.enable_hooks()
      end

      def delete!(changeset_or_query, opts) do
        changeset_or_query = @hooks.before_delete(changeset_or_query)

        changeset_or_query
        |> super(opts)
        |> @hooks.after_delete(changeset_or_query)
      after
        @hooks.enable_hooks()
      end

      def insert_or_update(
            %Ecto.Changeset{data: %{__meta__: %{state: :loaded}}} = changeset,
            opts
          ) do
        changeset = @hooks.before_update(changeset)

        with {:ok, result} <- super(changeset, opts) do
          {:ok, @hooks.after_update(result, changeset)}
        end
      after
        @hooks.enable_hooks()
      end

      def insert_or_update(
            %Ecto.Changeset{data: %{__meta__: %{state: :built}}} = changeset,
            opts
          ) do
        changeset = @hooks.before_insert(changeset)

        with {:ok, result} <- super(changeset, opts) do
          {:ok, @hooks.after_insert(result, changeset)}
        end
      after
        @hooks.enable_hooks()
      end

      def insert_or_update(changeset, opts) do
        super(changeset, opts)
      end

      def insert_or_update!(
            %Ecto.Changeset{data: %{__meta__: %{state: :loaded}}} = changeset,
            opts
          ) do
        changeset = @hooks.before_update(changeset)

        changeset
        |> super(opts)
        |> @hooks.after_update(changeset)
      after
        @hooks.enable_hooks()
      end

      def insert_or_update!(
            %Ecto.Changeset{data: %{__meta__: %{state: :built}}} = changeset,
            opts
          ) do
        changeset = @hooks.before_insert(changeset)

        changeset
        |> super(opts)
        |> @hooks.after_insert(changeset)
      after
        @hooks.enable_hooks()
      end

      def insert_or_update!(changeset, opts) do
        super(changeset, opts)
      end
    end
  end

  @doc """
  Disables EctoHooks from running for all future Repo operations in the current process.
  """
  def disable_hooks do
    Process.put({__MODULE__, :hooks_enabled}, false)
    :ok
  end

  @doc """
  Enables EctoHooks from running for all future Repo operations in the current process.
  """
  def enable_hooks do
    Process.put({__MODULE__, :hooks_enabled}, true)
    :ok
  end

  @doc """
  Returns a boolean indicating if EctoHooks are enabled in the current process.
  """
  def hooks_enabled? do
    Process.get({__MODULE__, :hooks_enabled}, true)
  end

  @before_callbacks [:before_delete, :before_insert, :before_update]
  @after_callbacks [:after_delete, :after_get, :after_insert, :after_update]

  for callback <- @before_callbacks do
    @doc false
    def unquote(callback)(%{__struct__: Ecto.Changeset, data: %schema{}} = changeset) do
      if hooks_enabled?() && function_exported?(schema, unquote(callback), 1) do
        disable_hooks()
        schema.unquote(callback)(changeset)
      else
        changeset
      end
    end

    def unquote(callback)(%schema{} = data) do
      if hooks_enabled?() && function_exported?(schema, unquote(callback), 1) do
        disable_hooks()
        schema.unquote(callback)(data)
      else
        data
      end
    end

    def unquote(callback)(changeset) do
      changeset
    end
  end

  for callback <- @after_callbacks do
    @doc false
    def unquote(callback)(%schema{} = data, changeset_query_or_schema) do
      if hooks_enabled?() && function_exported?(schema, unquote(callback), 2) do
        disable_hooks()
        schema.unquote(callback)(data, changeset_query_or_schema)
      else
        data
      end
    end

    def unquote(callback)(data) do
      data
    end
  end
end
