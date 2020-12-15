defmodule EctoHooks.Repo do
  @moduledoc """
  This module provides an alternate interface for initializing `EctoHooks`.

  Ordinarily, one would need to add the `use EctoHooks` statement to an `Ecto.Repo`
  implementation module in one's application.

  This module instead simply replaces the `use Ecto.Repo, ...` statement with the
  following:

  ```elixir
  defmodule MyApp.Repo do
    use EctoHooks.Repo,
      otp_app: :my_app,
      ...
  end
  ```

  Any paramters passed into `use EctoHooks.Repo` are simply forwarded to `Ecto.Repo`
  and `EctoHooks` functionality is automatically included.

  See the documentation to `EctoHooks` for more information.
  """

  defmacro __using__(opts) do
    quote do
      use Ecto.Repo, unquote(opts)
      use EctoHooks
    end
  end
end
