defmodule Ecto.Repo.HooksTest do
  defmodule Repo do
    use Ecto.Repo,
      otp_app: :ecto_hooks,
      adapter: Etso.Adapter

    use Ecto.Repo.Hooks
  end

  defmodule User do
    use Ecto.Schema
    import Ecto.Changeset

    require Logger

    schema "user" do
      field(:first_name, :string)
      field(:last_name, :string)

      field(:full_name, :string, virtual: true)
    end

    def after_insert(%__MODULE__{first_name: first_name, last_name: last_name} = data) do
      Logger.info("after insert")
      %__MODULE__{data | full_name: first_name <> " " <> last_name}
    end

    def changeset(%__MODULE__{} = user, attrs) do
      user
      |> cast(attrs, [:first_name, :last_name])
      |> validate_required([:first_name, :last_name])
    end
  end

  use ExUnit.Case
  import ExUnit.CaptureLog

  setup do
    {:ok, _} = start_supervised(%{id: __MODULE__, start: {Repo, :start_link, []}})
    :ok
  end

  describe "after_insert/1" do
    test "executes after successful Repo.insert/2" do
      assert capture_log(fn ->
               assert {:ok, user} =
                        %User{}
                        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
                        |> Repo.insert()

               assert user.full_name == "Bob Dylan"
             end) =~ "after insert"
    end

    test "executes after successful Repo.insert!/2" do
      assert capture_log(fn ->
               assert user =
                        %User{}
                        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
                        |> Repo.insert!()

               assert user.full_name == "Bob Dylan"
             end) =~ "after insert"
    end

    test "does not executes after unsuccessful Repo.insert/2" do
      refute capture_log(fn ->
               assert {:error, %Ecto.Changeset{}} =
                        %User{}
                        |> User.changeset(%{})
                        |> Repo.insert()
             end) =~ "after insert"
    end

    test "does not executes after unsuccessful Repo.insert!/2" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        assert %Ecto.Changeset{} =
                 %User{}
                 |> User.changeset(%{})
                 |> Repo.insert!()
      end
    end
  end
end
