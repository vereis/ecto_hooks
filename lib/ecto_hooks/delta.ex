defmodule EctoHooks.Delta do
  @moduledoc """
  Struct which is given as the 2nd argument to any `after_*` hook defined by EctoHooks.

  Contains metadata about the hook such as the particular Repo call which resulted in
  the hook being triggered, which hook was triggered, the source changeset, queryable,
  or struct which was passed into said Repo call.

  This can be particularly helpful for conditionally disabling or enabling hooks on
  a subset of triggers -- i.e. only when certain fields have changed in a given schema.

  In future, it might be possible for users to mark annotate certain Repo operations
  to trigger hooks only for those annotated functions. This is the mechanism by which
  that would work.
  """

  alias __MODULE__

  @enforce_keys [:operation, :hook, :source]
  defstruct [:operation, :hook, :source, :queryable, :changeset, :record]

  @operations [
    :all,
    :delete,
    :delete!,
    :get,
    :get!,
    :get_by,
    :get_by!,
    :insert,
    :insert!,
    :insert_or_update,
    :insert_or_update!,
    :one,
    :one!,
    :update,
    :update!
  ]

  @hooks [
    :before_delete,
    :before_insert,
    :before_update,
    :after_delete,
    :after_get,
    :after_insert,
    :after_update
  ]

  def new!(operation, hook, source) when operation in @operations and hook in @hooks do
    delta = %Delta{operation: operation, hook: hook, source: source}

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
end
