defmodule Ecto.Repo.Hooks do
  @moduledoc """
  When `use`-ed in a module that also `use`-es `Ecto.Repo`, augments the following
  `Ecto.Repo` callbacks to provide user definable hooks following successful
  execution.

  # Hooks to `MyApp.EctoSchema.after_get/1`
  - `all/2`
  - `get/3`
  - `get!/3`
  - `get_by/3`
  - `get_by!/3`
  - `one/2`
  - `one!/2`

  # Hooks to `MyApp.EctoSchema.after_delete/1`
  - `delete/2`
  - `delete!/2`

  # Hooks to `MyApp.EctoSchema.after_insert/1`
  - `insert/2`
  - `insert!/2`

  # Hooks to `MyApp.EctoSchema.after_update/1`
  - `update/2`
  - `update!/2`

  # Hooks to `MyApp.EctoSchema.after_insert/1` or to
  # `MyApp.Ecto.Schema.after_update/1`
  - `insert_or_update/2`
  - `insert_or_update!/2`
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
end
