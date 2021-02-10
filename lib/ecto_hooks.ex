defmodule EctoHooks do
  @moduledoc """
  When `use`-ed in a module that also `use`-es `Ecto.Repo`, augments the following
  `Ecto.Repo` callbacks to provide user definable hooks following successful
  execution.

  Hooks to `MyApp.EctoSchema.after_get/1`:
  - `all/2`
  - `get/3`
  - `get!/3`
  - `get_by/3`
  - `get_by!/3`
  - `one/2`
  - `one!/2`

  Hooks to `MyApp.EctoSchema.after_delete/1`:
  - `delete/2`
  - `delete!/2`

  Hooks to `MyApp.EctoSchema.after_insert/1`:
  - `insert/2`
  - `insert!/2`

  Hooks to `MyApp.EctoSchema.after_update/1`:
  - `update/2`
  - `update!/2`

  Hooks to `MyApp.EctoSchema.after_insert/1` or to `MyApp.Ecto.Schema.after_update/1`:
  - `insert_or_update/2`
  - `insert_or_update!/2`

  Please note that the result of executing a hook is the result ultimately returned
  a user, and thus you should aim to only modify a given database result.

  Any results wrapped within an `{:ok, _}` or `{:error, _}` are also returned re-wrapped
  as expected.

  The hooking functionality provided by `EctoHooks` can be pretty useful for resolving
  virtual fields, but can also prove useful for centralising some logging or telemetry
  logic. Note that because any business logic is executed synchronously after the
  hooked `Ecto.Repo` callback, one should avoid doing any blocking or potentially
  terminating logic within hooks as weird or strange behaviour may occur.

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
          {:ok, @hooks.after_insert(result)}
        end
      end

      def insert!(changeset, opts) do
        changeset
        |> @hooks.before_insert
        |> super(opts)
        |> @hooks.after_insert
      end

      def update(changeset, opts) do
        changeset = @hooks.before_update(changeset)

        with {:ok, result} <- super(changeset, opts) do
          {:ok, @hooks.after_update(result)}
        end
      end

      def update!(changeset, opts) do
        changeset
        |> @hooks.before_update
        |> super(opts)
        |> @hooks.after_update
      end

      def get(query, id, opts) do
        with %{__meta__: %Ecto.Schema.Metadata{}} = result <- super(query, id, opts) do
          @hooks.after_get(result)
        end
      end

      def get!(query, id, opts) do
        query
        |> super(id, opts)
        |> @hooks.after_get
      end

      def get_by(query, clauses, opts) do
        with %{__meta__: %Ecto.Schema.Metadata{}} = result <- super(query, clauses, opts) do
          @hooks.after_get(result)
        end
      end

      def get_by!(query, clauses, opts) do
        query
        |> super(clauses, opts)
        |> @hooks.after_get
      end

      def one(query, opts) do
        with %{__meta__: %Ecto.Schema.Metadata{}} = result <- super(query, opts) do
          @hooks.after_get(result)
        end
      end

      def one!(query, opts) do
        query
        |> super(opts)
        |> @hooks.after_get
      end

      def all(query, opts) do
        query
        |> super(opts)
        |> Enum.map(&@hooks.after_get/1)
      end

      def delete(changeset_or_query, opts) do
        changeset_or_query = @hooks.before_delete(changeset_or_query)

        with {:ok, result} <- super(changeset_or_query, opts) do
          {:ok, @hooks.after_delete(result)}
        end
      end

      def delete!(changeset_or_query, opts) do
        changeset_or_query
        |> @hooks.before_delete
        |> super(opts)
        |> @hooks.after_delete
      end

      def insert_or_update(
            %Ecto.Changeset{data: %{__meta__: %{state: :loaded}}} = changeset,
            opts
          ) do
        changeset = @hooks.before_update(changeset)

        with {:ok, result} <- super(changeset, opts) do
          {:ok, @hooks.after_update(result)}
        end
      end

      def insert_or_update(
            %Ecto.Changeset{data: %{__meta__: %{state: :built}}} = changeset,
            opts
          ) do
        changeset = @hooks.before_insert(changeset)

        with {:ok, result} <- super(changeset, opts) do
          {:ok, @hooks.after_insert(result)}
        end
      end

      def insert_or_update(changeset, opts) do
        super(changeset, opts)
      end

      def insert_or_update!(
            %Ecto.Changeset{data: %{__meta__: %{state: :loaded}}} = changeset,
            opts
          ) do
        changeset
        |> @hooks.before_update
        |> super(opts)
        |> @hooks.after_update
      end

      def insert_or_update!(
            %Ecto.Changeset{data: %{__meta__: %{state: :built}}} = changeset,
            opts
          ) do
        changeset
        |> @hooks.before_insert
        |> super(opts)
        |> @hooks.after_insert
      end

      def insert_or_update!(changeset, opts) do
        super(changeset, opts)
      end
    end
  end

  @before_callbacks [:before_delete, :before_insert, :before_update]
  @after_callbacks [:after_delete, :after_get, :after_insert, :after_update]

  for callback <- @before_callbacks do
    def unquote(callback)(%{__struct__: Ecto.Changeset, data: %schema{}} = changeset) do
      if function_exported?(schema, unquote(callback), 1) do
        schema.unquote(callback)(changeset)
      else
        changeset
      end
    end

    def unquote(callback)(%schema{} = data) do
      if function_exported?(schema, unquote(callback), 1) do
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
    def unquote(callback)(%schema{} = data) do
      if function_exported?(schema, unquote(callback), 1) do
        schema.unquote(callback)(data)
      else
        data
      end
    end

    def unquote(callback)(data) do
      data
    end
  end
end
