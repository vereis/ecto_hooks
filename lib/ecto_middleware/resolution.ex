defmodule EctoMiddleware.Resolution do
  @moduledoc "Struct for holding middleware resolution data"

  @type t :: %__MODULE__{}
  defstruct [
    :repo,
    :action,
    :args,
    :middleware,
    :entity,
    :before_middleware,
    :after_middleware,
    :before_input,
    :before_output,
    :after_input,
    :after_output
  ]

  defmacro new!(args) do
    {caller, _arity} = __CALLER__.function

    quote bind_quoted: [self: __MODULE__, action: caller, args: args] do
      entity = List.first(args)

      middleware = EctoMiddleware.middleware(__MODULE__, action, entity)

      {before_middleware, after_middleware} =
        EctoMiddleware.partition_middleware(__MODULE__, action, entity)

      struct!(self,
        repo: __MODULE__,
        entity: entity,
        action: action,
        args: args,
        middleware: middleware,
        before_middleware: before_middleware,
        after_middleware: after_middleware
      )
    end
  end

  @spec execute_before!(t()) :: t()
  def execute_before!(%__MODULE__{} = resolution) do
    resolution = %__MODULE__{resolution | before_input: List.first(resolution.args)}

    before_output =
      resolution
      |> Map.get(:before_middleware, [])
      |> Enum.reduce(resolution.before_input, & &1.middleware(&2, resolution))

    %__MODULE__{resolution | before_output: before_output}
  end

  @spec execute_after!(t(), input :: term()) :: t()
  def execute_after!(%__MODULE__{} = resolution, input) do
    resolution = %__MODULE__{resolution | after_input: input}

    after_output =
      resolution
      |> Map.get(:after_middleware, [])
      |> Enum.reduce(resolution.after_input, & &1.middleware(&2, resolution))

    %__MODULE__{resolution | after_output: after_output}
  end
end
