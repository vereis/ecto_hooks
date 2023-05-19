defmodule EctoMiddleware do
  @moduledoc """
  This module provides the `EctoMiddleware` behaviour, which extends any module that
  uses `Ecto.Repo` with the capability to hook into the execution of any `Ecto.Repo`
  callback (that reads/writes to said repo).

  ## Setup and initialization

  To enable `EctoMiddleware`, you must `use` this module in any of your `Ecto.Repo`
  modules.

  Once done, you will be able to customize the middleware you wish to run either before,
  or after any given `Ecto.Repo` callback (again, that reads/writes to said repo).

  By default, `EctoMiddleware` will not run any middleware. You must explicitly define
  them yourself.

  You're also able to customize the middleware you wish to run based on the given
  "action" or "resource" that an `Ecto.Repo` callback is being executed on.

  The "action" of a given `Ecto.Repo` callback is the name of the function being executed,
  without the arity. For example, the "action" of `get/3` is `get` and the "action" of
  `get!/3` is `get!`.

  The "resource" of a given `Ecto.Repo` is typically the first argument of the function
  being executed. For example, the "resource" of `get/3` is a module that uses
  `Ecto.Schema`.

  See the below example:

  ```elixir
  defmodule MyApp.Repo do
    use Ecto.Repo,
      otp_app: :my_app,
      adapter: Ecto.Adapters.Postgres

    use EctoMiddleware

    def middleware(action, _resource) when action in [:delete, :delete!] do
      [MyApp.EctoMiddleware.MaybeSoftDelete, EctoMiddleware.Super, MyApp.EctoMiddleware.Log]
    end

    def middleware(_action, _resource) do
      [EctoMiddleware.Super, MyApp.EctoMiddleware.Log]
    end
  end
  ```

  Any middleware preceding `EctoMiddleware.Super` will be executed before the given
  `Ecto.Repo` callback is executed.

  Any middleware following `EctoMiddleware.Super` will be executed after the given
  `Ecto.Repo` callback is executed.

  ## Writing Middleware

  To write your own middleware, you must implement the `EctoMiddleware` behaviour in a
  module of your choosing.

  The `EctoMiddleware` behaviour requires you to implement the `middleware/2` callback,
  which takes the "resource" of the given `Ecto.Repo` callback as the first argument,
  and an `EctoMiddleware.Resolution` struct as the second argument.

  All middleware must return a modified "resource" (or the original "resource" if no
  modifications were made).

  Additionally, any configured middleware is run synchronously, in the order they are
  defined.

  Please see the `EctoMiddleware.Resolution` struct for more information, but in short,
  the struct contains various bits of metadata about the given `Ecto.Repo` callback that is
  being executed, the inputs to the callback, and the result of the callback (if it has
  been executed).

  ### Before Middleware

  Any middleware preceding `EctoMiddleware.Super` will be executed before the given
  `Ecto.Repo` callback is executed.

  Because these middlewares run prior to the `Ecto.Repo` callback, they are able to
  modify the inputs to the callback, or even short-circuit the callback entirely,
  however, they are not able to modify the result of the callback (as it has not been
  executed yet).

  If you wish to modify the result of the callback, you must use an after middleware
  instead.

  ### After Middleware

  Any middleware following `EctoMiddleware.Super` will be executed after the given
  `Ecto.Repo` callback is executed.

  Because these middlewares run after the `Ecto.Repo` callback, they are able to
  modify the result of the callback, however, they are not able to modify the inputs
  to the callback (as it has already been executed).

  If you wish to modify the inputs to the callback, you must use a before middleware
  instead.

  After middleware are additionally able to reference both the result of the callback,
  and the result of running any before middleware, making it an ideal place to perform
  any advanced processing or logging.

  ## Considerations

  When writing middleware, you should be aware of the following:

    - If you are modifying the "resource" of the given `Ecto.Repo` callback, you should
      ensure that the "resource" is still valid for the given `Ecto.Repo` callback.

    - Middleware are run synchronously, in the order they are defined, and as such, you
      should be mindful of the performance implications of your middleware.

    - Any middleware that raises an exception will cause the given `Ecto.Repo` callback
      to raise an exception as well, regardless of whether or not the given `Ecto.Repo`
      callback has been executed or semantically is expected to raise an exception.

    - Middleware may be a place where dialyzer warnings are suppressed, as it may
      not be possible for dialyzer to infer the types returned out of any given middleware.

    - It is not possible to modify the "action" of the given `Ecto.Repo` callback, only the
      "resource".

    - Ideally, middleware should be written in such a way that they are reusable across
      multiple `Ecto.Repo` modules, "actions", or "resources". It is not recommended to
      to write middleware that is too strongly coupled to the prior or future middleware
      expected to have/be run.

    - Due to how the given `Ecto.Repo` callback is executed, it is not at this time
      possible to provide any transactional guarantees for middleware. If you wish to
      perform any transactional work, you should do so within your application's
      business logic, and not within any middleware.

  ## Testing

  You may test your middleware modules in a variety of ways:

    - You can test your middleware modules in the context of your application's business
      logic, by stubbing any `Ecto.Repo` callbacks that you wish to test.

    - You can either test your middleware modules in isolation, stubbing any "action" or
      "resource" that you wish to test.

    - You can directly test them by way of executing the given `Ecto.Repo` callback
      against a test database, and asserting on the result.

    - You can use the `EctoMiddleware.Resolution.execute_before!/1` and
      `EctoMiddleware.Resolution.execute_after!/2` to directly test middleware.

  In the future, more work will be done to enable easier testing of individual middleware.
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

  @doc "Enables the ability for a given `Ecto.Repo` to define and execute middleware."
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
  @doc false
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
  @doc false
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
  @doc false
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
