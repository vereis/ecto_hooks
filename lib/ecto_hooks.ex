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
  end
end
