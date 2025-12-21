defmodule EctoHooks.Delta do
  @moduledoc """
  Metadata struct passed to `after_*` hooks containing information about the operation.

  The Delta struct provides context about which repository operation triggered the hook,
  allowing for conditional logic and introspection within your hooks.

  ## Fields

  - `:repo_callback` - The `c:Ecto.Repo` function that was called (e.g., `:insert` for `c:Ecto.Repo.insert/2`, `:get` for `c:Ecto.Repo.get/3`)
  - `:hook` - The hook currently executing (e.g., `:after_insert`, `:after_get`)
  - `:source` - The original input to the repo operation (changeset, queryable, or struct)
  - `:queryable` - Set if source is an `t:Ecto.Queryable.t/0` (query or schema module)
  - `:changeset` - Set if source is an `t:Ecto.Changeset.t/0`
  - `:record` - Set if source is a schema struct or list

  ## Examples

  ### Conditional Hook Logic

      def after_get(user, %Delta{repo_callback: :get}) do
        # Only log when fetching single users via c:Ecto.Repo.get/3
        # (not during c:Ecto.Repo.all/2)
        Logger.info("Fetched user: \#{user.id}")
        user
      end

      def after_get(user, %Delta{repo_callback: :all}) do
        # Skip logging for bulk fetches via c:Ecto.Repo.all/2
        user
      end

  ### Inspecting Changes

      def after_update(user, %Delta{changeset: changeset}) do
        if Ecto.Changeset.changed?(changeset, :email) do
          EmailVerification.send_confirmation(user)
        end
        user
      end

  ### Delegating to Private Functions

      def after_insert(user, delta), do: handle_after_hook(user, delta)
      def after_update(user, delta), do: handle_after_hook(user, delta)

      defp handle_after_hook(user, %Delta{hook: :after_insert}) do
        # Logic specific to inserts
        send_welcome_email(user)
        user
      end

      defp handle_after_hook(user, %Delta{hook: :after_update}) do
        # Logic specific to updates
        invalidate_cache(user)
        user
      end

  ## Type

  The Delta struct is defined as:

      @type t :: %__MODULE__{
        repo_callback: repo_callback(),
        hook: hook(),
        source: term(),
        queryable: Ecto.Queryable.t() | nil,
        changeset: Ecto.Changeset.t() | nil,
        record: struct() | [struct()] | nil
      }

  Where `repo_callback()` is one of:
  - `:all` (`c:Ecto.Repo.all/2`)
  - `:delete` (`c:Ecto.Repo.delete/2`)
  - `:delete!` (`c:Ecto.Repo.delete!/2`)
  - `:get` (`c:Ecto.Repo.get/3`)
  - `:get!` (`c:Ecto.Repo.get!/3`)
  - `:get_by` (`c:Ecto.Repo.get_by/3`)
  - `:get_by!` (`c:Ecto.Repo.get_by!/3`)
  - `:insert` (`c:Ecto.Repo.insert/2`)
  - `:insert!` (`c:Ecto.Repo.insert!/2`)
  - `:insert_or_update` (`c:Ecto.Repo.insert_or_update/2`)
  - `:insert_or_update!` (`c:Ecto.Repo.insert_or_update!/2`)
  - `:one` (`c:Ecto.Repo.one/2`)
  - `:one!` (`c:Ecto.Repo.one!/2`)
  - `:preload` (`c:Ecto.Repo.preload/3`)
  - `:reload` (`c:Ecto.Repo.reload/2`)
  - `:reload!` (`c:Ecto.Repo.reload!/2`)
  - `:update` (`c:Ecto.Repo.update/2`)
  - `:update!` (`c:Ecto.Repo.update!/2`)

  And `hook()` is one of: `:after_delete`, `:after_get`, `:after_insert`, `:after_update`,
  `:before_delete`, `:before_insert`, `:before_update`
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
    :preload,
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
  # NOTE: The `cond` pattern is nicer than doing this with other
  #       branching constructs, but leads to a high cyclomatic complexity.
  #       This *could* be done via multiple function heads, but I found
  #       that to be less readable.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
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

      is_list(source) ->
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
