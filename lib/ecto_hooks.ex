defmodule EctoHooks do
  @moduledoc """
  Module exposing various utility functions for interacting with, and introspecting
  the state of EctoHooks.

  For more extensive usage instructions, please see associated documentation for
  `EctoHooks.Repo`.
  """

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

  # Hack: I don't want to add any dependencies I don't need to this library, so
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

  @doc """
  Alternative interface for initializing EctoHooks when `use`-ed in a module as follows:

  ```elixir
  def MyApp.Repo do
    use Ecto.Repo,
      otp_app: :my_app,
      adapter: Ecto.Adapters.Postgres

    use EctoHooks
  end
  ```

  Please see `EctoHooks.Repo` for more information about EctoHooks usage, examples,
  and considerations.
  """
  defmacro __using__(_opts) do
    quote do
      require EctoHooks.Repo
      EctoHooks.Repo.override_repo_callbacks()
    end
  end

  @doc """
  Ensures EctoHooks run for all future Repo operations in the current process.

  Internally, we use it to scope re-enabling hooks per execution, as we disabled
  them as a mitigation for infinitely looping hooks caused by hooks triggering
  other hooks. This happens when provided `[global: false]`, which should only be
  done internally.
  """
  @spec enable_hooks(Keyword.t()) :: :ok
  defdelegate enable_hooks(opts \\ [global: true]), to: State

  @doc """
  Disables EctoHooks running for all future Repo operations in the current process.

  Internally, this is called with the options `[global: false]` which gets
  automatically cleared after triggering any `Ecto.Repo` callback.
  """
  @spec disable_hooks(Keyword.t()) :: :ok
  defdelegate disable_hooks(opts \\ [global: true]), to: State

  @doc """
  Returns a boolean indicating if any `before_*` or `after_*` hooks are allowed
  to execute in the current process.

  Note that calls to `Ecto.Repo` callbacks may reset or change the state of this flag,
  and that this function is primarily exposed for introspection or debugging purposes.
  """
  @spec hooks_enabled?() :: boolean()
  defdelegate hooks_enabled?, to: State

  @doc """
  Utility function which returns true if currently executing inside the context of an
  Ecto Hook.
  """
  @spec in_hook?() :: boolean()
  defdelegate in_hook?, to: State

  @doc """
  Utility function which returns the "nesting" of the current EctoHooks context.

  By default, every hook will "acquire" an EctoHook context and increment a ref count.
  These ref counts are automatically decremented once a hook finishes running.

  This is provided as a lower level alternative the `enable_hooks/1`, `disable_hooks/1`,
  and `hooks_enabled?/0` functions.
  """
  @spec hooks_ref_count() :: pos_integer()
  defdelegate hooks_ref_count, to: State

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
    %struct{function: ^hook} when struct in [UndefinedFunctionError, FunctionClauseError] ->
      param_1
  after
    :ok = State.enable_hooks(global: false)
    :ok = State.release_hook()
  end
end
