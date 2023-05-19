defmodule EctoMiddleware do
  @moduledoc """
  NOTE: TBA
  """

  alias EctoMiddleware.Resolution

  @type action ::
          :all
          | :delete!
          | :delete
          | :get!
          | :get
          | :get_by!
          | :get_by
          | :insert!
          | :insert
          | :insert_or_update!
          | :insert_or_update
          | :one!
          | :one
          | :reload!
          | :reload
          | :preload
          | :update!
          | :update

  @type resource ::
          %{__struct__: Ecto.Queryable}
          | %{__struct__: Ecto.Changeset}
          | %{__meta__: Ecto.Schema.Metadata}
          | {%{__struct__: Ecto.Queryable}, Keyword.t()}

  @type middleware :: [module()]
  @callback middleware(resource :: resource(), resolution :: Resolution.t()) :: resource()

  @doc "Returns the configured middleware for the given repo."
  @spec middleware(repo :: module(), action(), resource()) :: [middleware()]
  def middleware(repo, action, resource) when is_atom(repo) do
    repo.middleware(action, resource)
  end

  @doc """
  Returns the configured middleware for the given repo, partitioning by whether or not
  the middleware is intended to run before or after the repo callback.
  """
  @spec partition_middleware(repo :: module(), action(), resource()) ::
          {[middleware()], [middleware()]}
  def partition_middleware(repo, action, resource) do
    {_mode, {before_middleware, after_middleware}} =
      repo
      |> middleware(action, resource)
      |> Enum.reverse()
      |> Enum.reduce({:after, {[], []}}, fn
        EctoMiddleware.Super, {:after, {before_middleware, after_middleware}} ->
          {:before, {before_middleware, after_middleware}}

        middleware, {:before, {before_middleware, after_middleware}} ->
          {:before, {[middleware | before_middleware], after_middleware}}

        middleware, {:after, {before_middleware, after_middleware}} ->
          {:after, {before_middleware, [middleware | after_middleware]}}
      end)

    {before_middleware, after_middleware}
  end

  defmacro __using__(_opts) do
    quote location: :keep do
      @typep middleware :: EctoMiddleware.middleware()
      @typep action :: EctoMiddleware.action()
      @typep resource :: EctoMiddleware.resource()

      import EctoMiddleware
      require EctoMiddleware.Resolution, as: Resolution
      require EctoMiddleware
      alias __MODULE__, as: Self

      @spec middleware(action(), resource()) :: [middleware()]
      def middleware(_action, _resource), do: [EctoMiddleware.Super]

      defoverridable middleware: 2,
                     all: 2,
                     delete!: 2,
                     delete: 2,
                     get!: 3,
                     get: 3,
                     get_by!: 3,
                     get_by: 3,
                     insert!: 2,
                     insert: 2,
                     insert_or_update!: 2,
                     insert_or_update: 2,
                     one!: 2,
                     one: 2,
                     reload!: 2,
                     reload: 2,
                     preload: 3,
                     update!: 2,
                     update: 2

      stub_optimistic_functions!()
      stub_ok_error_functions!()
      stub_bang_functions!()
    end
  end

  # Automatically execute before and after middleware for the given functions.
  # These functions return either a list, an ecto schema struct, or arbitary values.
  # For lists and ecto schemas, ensure the before and after middlewares are executed.
  defmacro stub_optimistic_functions! do
    import Macro
    c = __MODULE__

    arity_2 = [:one, :all, :reload, :reload!]
    arity_3 = [:preload, :get_by, :get]

    for {fun, arity} <- Enum.map(arity_2, &{&1, 2}) ++ Enum.map(arity_3, &{&1, 3}) do
      quote do
        def unquote(fun)(unquote_splicing(generate_arguments(arity, c))) do
          resolution = Resolution.new!([unquote_splicing(generate_arguments(arity, c))])
          resolution = Resolution.execute_before!(resolution)

          input = resolution.before_output

          case super(unquote_splicing([var(:input, c) | tl(generate_arguments(arity, c))])) do
            results when is_list(results) ->
              Enum.map(results, &Resolution.execute_after!(resolution, &1).after_output)

            %{__meta__: %Ecto.Schema.Metadata{}} = result ->
              Resolution.execute_after!(resolution, result).after_output

            otherwise ->
              otherwise
          end
        end
      end
    end
  end

  # Automatically execute before and after middleware for the given functions.
  # These functions return either `{:ok, term()}` or `{:error, term()}`.
  # For `{:ok, term()}`, ensure the before and after middlewares are executed.
  defmacro stub_ok_error_functions! do
    import Macro
    c = __MODULE__

    arity_2 = [:insert_or_update, :delete, :update, :insert]
    arity_3 = []

    for {fun, arity} <- Enum.map(arity_2, &{&1, 2}) ++ Enum.map(arity_3, &{&1, 3}) do
      quote do
        def unquote(fun)(unquote_splicing(generate_arguments(arity, c))) do
          resolution = Resolution.new!([unquote_splicing(generate_arguments(arity, c))])
          resolution = Resolution.execute_before!(resolution)

          input = resolution.before_output

          case super(unquote_splicing([var(:input, c) | tl(generate_arguments(arity, c))])) do
            {:ok, result} ->
              {:ok, Resolution.execute_after!(resolution, result).after_output}

            {:error, reason} ->
              {:error, reason}
          end
        end
      end
    end
  end

  # Automatically execute before and after middleware for the given functions.
  # These functions either return valid outputs or raise an error.
  # For valid outputs, ensure the before and after middlewares are executed.
  defmacro stub_bang_functions! do
    import Macro
    c = __MODULE__

    arity_2 = [:insert_or_update!, :delete!, :one!, :update!, :insert!]
    arity_3 = [:get!, :get_by!]

    for {fun, arity} <- Enum.map(arity_2, &{&1, 2}) ++ Enum.map(arity_3, &{&1, 3}) do
      quote do
        def unquote(fun)(unquote_splicing(generate_arguments(arity, c))) do
          resolution = Resolution.new!([unquote_splicing(generate_arguments(arity, c))])
          resolution = Resolution.execute_before!(resolution)

          input = resolution.before_output
          result = super(unquote_splicing([var(:input, c) | tl(generate_arguments(arity, c))]))

          Resolution.execute_after!(resolution, result).after_output
        end
      end
    end
  end
end
