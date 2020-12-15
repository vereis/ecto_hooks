defmodule Ecto.Repo.HooksTest do
  defmodule Repo do
    use Ecto.Repo.Hooks

    use Ecto.Repo,
      otp_app: :ecto_hooks,
      adapter: Etso.Adapter
  end

  defmodule User do
    use Ecto.Schema
    import Ecto.Changeset

    schema "user" do
      field(:first_name, :string)
      field(:last_name, :string)

      field(:full_name, :string, virtual: true)
    end

    def changeset(%__MODULE__{} = user, attrs) do
      user
      |> cast(attrs, [:first_name, :last_name])
    end
  end

  use ExUnit.Case

  setup do
    repo_start = {Repo, :start_link, []}
    {:ok, _} = start_supervised(%{id: __MODULE__, start: {Repo, :start_link, []}})

    :ok
  end
end
