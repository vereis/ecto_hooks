defmodule EctoHooks.Delta do
  @moduledoc """
  Defines the struct which is given as the 2nd argument to any `after_*` hooks.

  Contains metadata which may be useful for introspecting or otherwise conditionally
  running hooks only when certain conditions are met.

  The following information is present in an `EctoHooks.Delta`:

  - The `Ecto.Repo` callback that triggered the hook
  - The name of the current hook (useful if delegating to private functions in your schema)
  - The `Ecto.Queryable` passed into the triggering `Ecto.Repo` callback if any
  - The `Ecto.Changeset` passed into the triggering `Ecto.Repo` callback if any
  """

  alias __MODULE__

  @type t :: %__MODULE__{}

  @enforce_keys [:repo_callback, :hook, :source]
  defstruct [:repo_callback, :hook, :source, :queryable, :changeset, :record]

  @repo_callbacks [
    :all,
    :delete!,
    :delete,
    :get!,
    :get,
    :get_by!,
    :get_by,
    :insert!,
    :insert,
    :insert_or_update!,
    :insert_or_update,
    :one!,
    :one,
    :reload!,
    :reload,
    :update!,
    :update
  ]

  @hooks [
    :after_delete,
    :after_get,
    :after_insert,
    :after_update,
    :before_delete,
    :before_insert,
    :before_update
  ]

  @type repo_callback :: unquote(Enum.reduce(@repo_callbacks, &{:|, [], [&1, &2]}))
  @type hook :: unquote(Enum.reduce(@hooks, &{:|, [], [&1, &2]}))

  @spec new!(repo_callback(), hook(), source :: any()) :: __MODULE__.t() | no_return()
  def new!(repo_callback, hook, source)
      when repo_callback in @repo_callbacks and hook in @hooks do
    delta = %Delta{repo_callback: repo_callback, hook: hook, source: source}

    cond do
      match?(%{__struct__: Ecto.Changeset}, source) ->
        %Delta{delta | changeset: source}

      match?(%{__struct__: Ecto.Query}, source) ->
        %Delta{delta | queryable: source}

      is_atom(source) && function_exported?(source, :__schema__, 2) ->
        %Delta{delta | queryable: source}

      is_struct(source) && function_exported?(source.__struct__, :__schema__, 2) ->
        %Delta{delta | record: source}

      true ->
        delta
    end
  end

  @doc false
  def repo_callbacks do
    @repo_callbacks
  end

  @doc false
  def hooks do
    @hooks
  end
end
