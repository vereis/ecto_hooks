defmodule EctoHooks.State do
  @moduledoc false

  @doc """
  Disables EctoHooks from running for all future Repo operations in the current process.
  """
  def disable_hooks, do: put_state(:hooks_enabled, false)

  @doc """
  Enables EctoHooks from running for all future Repo operations in the current process.
  """
  def enable_hooks, do: put_state(:hooks_enabled, true)

  @doc """
  Returns a boolean indicating if EctoHooks are enabled in the current process.

  If `true`, hooks will not be triggered for Repo operations.
  """
  def hooks_enabled?, do: get_state(:hooks_enabled, true)

  @doc """
  Utility function which returns true if currently executing inside the context of an
  Ecto Hook.
  """
  def in_hook?, do: get_state(:ref_count, 0) > 0

  @doc """
  Utility function which returns the "nesting" of the current EctoHooks context.

  By default, every hook will "acquire" an EctoHook context and increment a ref count.
  These ref counts are automatically decremented once a hook finishes running.

  This is provided as a lower level alternative the `enable_hooks/0`, `disable_hooks/0`,
  and `hooks_enabled?/0` functions.
  """
  def hooks_ref_count, do: get_state(:ref_count, 0)

  @doc false
  def acquire_hook, do: put_state(:ref_count, get_state(:ref_count, 0) + 1)

  @doc false
  def release_hook, do: put_state(:ref_count, max(get_state(:ref_count, 0) - 1, 0))

  # === Helpers for keeping process dictionary keys in our own namespace ===
  defp put_state(key, value) do
    key
    |> build_key()
    |> Process.put(value)

    :ok
  end

  defp get_state(key, default) do
    key
    |> build_key()
    |> Process.get(default)
  end

  defp build_key(key), do: {__MODULE__, key}
end
