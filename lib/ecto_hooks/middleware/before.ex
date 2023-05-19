defmodule EctoHooks.Middleware.Before do
  @moduledoc "Module containing implementation for all `before_` hooks"

  @behaviour EctoMiddleware

  @impl EctoMiddleware
  def middleware(resource, resolution) when resolution.action in [:insert, :insert!] do
    EctoHooks.before_insert(resource, resolution.action)
  end

  def middleware(resource, resolution) when resolution.action in [:update, :update!] do
    EctoHooks.before_update(resource, resolution.action)
  end

  def middleware(resource, resolution) when resolution.action in [:delete, :delete!] do
    EctoHooks.before_delete(resource, resolution.action)
  end

  def middleware(resource, resolution)
      when resolution.action in [:insert_or_update, :insert_or_update!] and
             resource.data.__meta__.state == :loaded do
    EctoHooks.before_update(resource, resolution.action)
  end

  def middleware(resource, resolution)
      when resolution.action in [:insert_or_update, :insert_or_update!] and
             resource.data.__meta__.state == :built do
    EctoHooks.before_insert(resource, resolution.action)
  end

  def middleware(resource, _resolution) do
    resource
  end
end
