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

      def insert(changeset, opts) do
        resolution = Resolution.new!([changeset, opts])
        resolution = Resolution.execute_before!(resolution)

        case super(resolution.before_output, opts) do
          {:ok, result} ->
            {:ok, Resolution.execute_after!(resolution, result).after_output}

          {:error, reason} ->
            {:error, reason}
        end
      end

      def insert!(changeset, opts) do
        resolution = Resolution.new!([changeset, opts])
        resolution = Resolution.execute_before!(resolution)

        result = super(resolution.before_output, opts)
        Resolution.execute_after!(resolution, result).after_output
      end

      def update(changeset, opts) do
        resolution = Resolution.new!([changeset, opts])
        resolution = Resolution.execute_before!(resolution)

        case super(resolution.before_output, opts) do
          {:ok, result} ->
            {:ok, Resolution.execute_after!(resolution, result).after_output}

          {:error, reason} ->
            {:error, reason}
        end
      end

      def update!(changeset, opts) do
        resolution = Resolution.new!([changeset, opts])
        resolution = Resolution.execute_before!(resolution)
        result = super(resolution.before_output, opts)
        Resolution.execute_after!(resolution, result).after_output
      end

      def get(query, id, opts) do
        resolution = Resolution.new!([query, id, opts])
        resolution = Resolution.execute_before!(resolution)

        with %{__meta__: %Ecto.Schema.Metadata{}} = result <-
               super(resolution.before_output, id, opts) do
          Resolution.execute_after!(resolution, result).after_output
        end
      end

      def get!(query, id, opts) do
        resolution = Resolution.new!([query, id, opts])
        resolution = Resolution.execute_before!(resolution)
        %{__meta__: %Ecto.Schema.Metadata{}} = result = super(resolution.before_output, id, opts)
        resolution = %Resolution{resolution | before_input: query, after_input: result}
        Resolution.execute_after!(resolution, result).after_output
      end

      def get_by(query, clauses, opts) do
        resolution = Resolution.new!([query, clauses, opts])
        resolution = Resolution.execute_before!(resolution)

        with %{__meta__: %Ecto.Schema.Metadata{}} = result <-
               super(resolution.before_output, clauses, opts) do
          Resolution.execute_after!(resolution, result).after_output
        end
      end

      def get_by!(query, clauses, opts) do
        resolution = Resolution.new!([query, clauses, opts])
        resolution = Resolution.execute_before!(resolution)

        %{__meta__: %Ecto.Schema.Metadata{}} =
          result = super(resolution.before_output, clauses, opts)

        resolution = %Resolution{resolution | before_input: query, after_input: result}
        Resolution.execute_after!(resolution, result).after_output
      end

      def one(query, opts) do
        resolution = Resolution.new!([query, opts])
        resolution = Resolution.execute_before!(resolution)

        case super(resolution.before_output, opts) do
          %{__meta__: %Ecto.Schema.Metadata{}} = result ->
            Resolution.execute_after!(resolution, result).after_output

          error ->
            error
        end
      end

      def one!(query, opts) do
        resolution = Resolution.new!([query, opts])
        resolution = Resolution.execute_before!(resolution)
        result = super(resolution.before_output, opts)
        Resolution.execute_after!(resolution, result).after_output
      end

      def all(query, opts) do
        resolution = Resolution.new!([query, opts])
        resolution = Resolution.execute_before!(resolution)

        case super(resolution.before_output, opts) do
          result when is_list(result) ->
            Enum.map(result, &Resolution.execute_after!(resolution, &1).after_output)

          error ->
            error
        end
      end

      def reload(struct_or_structs, opts) do
        resolution = Resolution.new!([struct_or_structs, opts])
        resolution = Resolution.execute_before!(resolution)

        case super(resolution.before_output, opts) do
          results when is_list(results) ->
            Enum.map(results, &Resolution.execute_after!(resolution, &1).after_output)

          %{__meta__: %Ecto.Schema.Metadata{}} = result ->
            Resolution.execute_after!(resolution, result).after_output
        end
      end

      def reload!(struct_or_structs, opts) do
        resolution = Resolution.new!([struct_or_structs, opts])
        resolution = Resolution.execute_before!(resolution)

        case super(resolution.before_output, opts) do
          results when is_list(results) ->
            Enum.map(results, &Resolution.execute_after!(resolution, &1).after_output)

          %{__meta__: %Ecto.Schema.Metadata{}} = result ->
            Resolution.execute_after!(resolution, result).after_output
        end
      end

      def preload(struct_or_structs, preloads, opts) do
        resolution = Resolution.new!([struct_or_structs, preloads, opts])
        resolution = Resolution.execute_before!(resolution)

        case super(resolution.before_output, preloads, opts) do
          results when is_list(results) ->
            Enum.map(results, &Resolution.execute_after!(resolution, &1).after_output)

          %{__meta__: %Ecto.Schema.Metadata{}} = result ->
            Resolution.execute_after!(resolution, result).after_output

          otherwise ->
            otherwise
        end
      end

      def delete(changeset_or_query, opts) do
        resolution = Resolution.new!([changeset_or_query, opts])
        resolution = Resolution.execute_before!(resolution)

        case super(resolution.before_output, opts) do
          {:ok, result} ->
            Resolution.execute_after!(resolution, result).after_output

          error ->
            error
        end
      end

      def delete!(changeset_or_query, opts) do
        resolution = Resolution.new!([changeset_or_query, opts])
        resolution = Resolution.execute_before!(resolution)
        result = super(resolution.before_output, opts)
        Resolution.execute_after!(resolution, result).after_output
      end

      def insert_or_update(changeset, opts) do
        resolution = Resolution.new!([changeset, opts])
        resolution = Resolution.execute_before!(resolution)

        case super(resolution.before_output, opts) do
          {:ok, result} ->
            {:ok, Resolution.execute_after!(resolution, result).after_output}

          {:error, reason} ->
            {:error, reason}
        end
      end

      def insert_or_update!(changeset, opts) do
        resolution = Resolution.new!([changeset, opts])
        resolution = Resolution.execute_before!(resolution)
        result = super(resolution.before_output, opts)
        Resolution.execute_after!(resolution, result).after_output
      end
    end
  end
end
