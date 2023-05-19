defmodule EctoMiddleware.Super do
  @moduledoc """
  Default middleware for Ecto repos.

  This middleware doesn't actually do anything; and is used largely to determine
  what middleware needs to run either before or after a given repo callback.

  See `#{inspect(&EctoMiddleware.partition_middleware/3)}` for more information.
  """

  @behaviour EctoMiddleware

  @impl EctoMiddleware
  def middleware(resource, _state), do: resource
end
