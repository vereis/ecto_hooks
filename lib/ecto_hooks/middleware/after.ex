defmodule EctoHooks.Middleware.After do
  @moduledoc "Module containing implementation for all `after_` hooks"

  @behaviour EctoMiddleware

  @impl EctoMiddleware
  def middleware(resource, resolution) when resolution.action in [:insert, :insert!] do
    EctoHooks.after_insert(resource, resolution.action, resolution.before_output)
  end

  def middleware(resource, resolution) when resolution.action in [:update, :update!] do
    EctoHooks.after_update(resource, resolution.action, resolution.before_output)
  end

  def middleware(resource, resolution) when resolution.action in [:delete, :delete!] do
    EctoHooks.after_delete(resource, resolution.action, resolution.before_output)
  end

  def middleware(resource, resolution)
      when resolution.action in [:insert_or_update, :insert_or_update!] and
             resolution.entity.data.__meta__.state == :loaded do
    EctoHooks.after_update(resource, resolution.action, resolution.before_output)
  end

  def middleware(resource, resolution)
      when resolution.action in [:insert_or_update, :insert_or_update!] and
             resolution.entity.data.__meta__.state == :built do
    EctoHooks.after_insert(resource, resolution.action, resolution.before_output)
  end

  def middleware(resource, resolution) when resolution.action in [:preload, :preload!] do
    case Enum.at(resolution.args, 1) do
      preloads when is_list(preloads) ->
        handle_preloads(resource, preloads)

      preload when is_atom(preload) ->
        handle_preloads(resource, [preload])

      _otherwise ->
        resource
    end
  end

  def middleware(resource, resolution)
      when resolution.action in [
             :get,
             :get!,
             :get_by,
             :get_by!,
             :one,
             :one!,
             :reload,
             :reload!,
             :all,
             :reload,
             :reload!
           ] do
    EctoHooks.after_get(resource, resolution.action, resolution.before_output)
  end

  def middleware(resource, _resolution) do
    resource
  end

  defp handle_preloads(structs, preloads) when is_list(structs) do
    Enum.map(structs, fn struct -> handle_preloads(struct, preloads) end)
  end

  defp handle_preloads(struct, preloads) do
    struct
    |> traverse_preloads(preloads)
    |> EctoHooks.after_get(:preload, struct)
  end

  defp traverse_preloads(nil, _preloads), do: nil

  defp traverse_preloads(struct, preloads) when is_list(preloads) do
    Enum.reduce(preloads, struct, fn preload, acc -> traverse_preloads(acc, preload) end)
  end

  defp traverse_preloads(struct, {preload, nested_preloads}) do
    {_, updated_struct} =
      Map.get_and_update(struct, preload, fn v ->
        {v, handle_preloads(v, nested_preloads)}
      end)

    updated_struct
  end

  defp traverse_preloads(struct, preload) when is_atom(preload) do
    {_, updated_struct} =
      Map.get_and_update(struct, preload, fn v ->
        {v, handle_preloads(v, [])}
      end)

    updated_struct
  end

  defp traverse_preloads(queryable, _preload) do
    queryable
  end
end
