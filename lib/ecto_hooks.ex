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

      def insert(query, opts) do
        with {:ok, result} <- super(query, opts) do
          {:ok, @hooks.after_insert(result)}
        end
      end

      def insert!(query, opts) do
        query
        |> super(opts)
        |> @hooks.after_insert
      end

      def update(query, opts) do
        with {:ok, result} <- super(query, opts) do
          {:ok, @hooks.after_update(result)}
        end
      end

      def update!(query, opts) do
        query
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

      def delete(query, opts) do
        with {:ok, result} <- super(query, opts) do
          {:ok, @hooks.after_delete(result)}
        end
      end

      def delete!(query, opts) do
        query
        |> super(opts)
        |> @hooks.after_delete
      end

      def insert_or_update(
            %Ecto.Changeset{data: %{__meta__: %{state: :built}}} = changeset,
            opts
          ) do
        with {:ok, result} <- super(changeset, opts) do
          {:ok, @hooks.after_insert(result)}
        end
      end

      def insert_or_update!(
            %Ecto.Changeset{data: %{__meta__: %{state: :built}}} = changeset,
            opts
          ) do
        changeset
        |> super(opts)
        |> @hooks.after_insert
      end

      def insert_or_update(
            %Ecto.Changeset{data: %{__meta__: %{state: :loaded}}} = changeset,
            opts
          ) do
        with {:ok, result} <- super(changeset, opts) do
          {:ok, @hooks.after_update(result)}
        end
      end

      def insert_or_update!(
            %Ecto.Changeset{data: %{__meta__: %{state: :loaded}}} = changeset,
            opts
          ) do
        changeset
        |> super(opts)
        |> @hooks.after_update
      end

      def insert_or_update(changeset, opts) do
        super(changeset, opts)
      end

      def insert_or_update!(changeset, opts) do
        super(changeset, opts)
      end
    end
  end

  def after_insert(%schema{} = data) do
    if function_exported?(schema, :after_insert, 1) do
      schema.after_insert(data)
    else
      data
    end
  end

  def after_insert(data) do
    data
  end

  def after_update(%schema{} = data) do
    if function_exported?(schema, :after_update, 1) do
      schema.after_update(data)
    else
      data
    end
  end

  def after_update(data) do
    data
  end

  def after_get(%schema{} = data) do
    if function_exported?(schema, :after_get, 1) do
      schema.after_get(data)
    else
      data
    end
  end

  def after_get(data) do
    data
  end

  def after_delete(%schema{} = data) do
    if function_exported?(schema, :after_delete, 1) do
      schema.after_delete(data)
    else
      data
    end
  end

  def after_delete(data) do
    data
  end
end
