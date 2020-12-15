defmodule Ecto.Repo.HooksTest do
  defmodule Repo do
    use EctoHooks.Repo,
      otp_app: :ecto_hooks,
      adapter: Etso.Adapter
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

    def after_update(%__MODULE__{first_name: first_name, last_name: last_name} = data) do
      Logger.info("after update")
      %__MODULE__{data | full_name: first_name <> " " <> last_name}
    end

    def after_get(%__MODULE__{first_name: first_name, last_name: last_name} = data) do
      Logger.info("after get")
      %__MODULE__{data | full_name: first_name <> " " <> last_name}
    end

    def after_delete(%__MODULE__{first_name: first_name, last_name: last_name} = data) do
      Logger.info("after delete")
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
  import Ecto.Query

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

    test "executes after successful Repo.insert_or_update/2 if it inserted" do
      assert capture_log(fn ->
               assert {:ok, user} =
                        %User{}
                        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
                        |> Repo.insert_or_update()

               assert user.full_name == "Bob Dylan"
             end) =~ "after insert"
    end

    test "executes after successful Repo.insert_or_update!/2 if it inserted" do
      assert capture_log(fn ->
               assert user =
                        %User{}
                        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
                        |> Repo.insert_or_update!()

               assert user.full_name == "Bob Dylan"
             end) =~ "after insert"
    end

    test "does not executes after unsuccessful Repo.insert_or_update/2 if it inserted" do
      refute capture_log(fn ->
               assert {:error, %Ecto.Changeset{}} =
                        %User{}
                        |> User.changeset(%{first_name: "Bob"})
                        |> Repo.insert_or_update()
             end) =~ "after insert"
    end

    test "does not executes after unsuccessful Repo.insert_or_update!/2 if it inserted" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        assert %Ecto.Changeset{} =
                 %User{}
                 |> User.changeset(%{})
                 |> Repo.insert_or_update!()
      end
    end
  end

  describe "after_update/1" do
    setup do
      Logger.configure(level: :error)

      {:ok, user} =
        %User{}
        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
        |> Repo.insert()

      Logger.configure(level: :info)

      {:ok, user: user}
    end

    test "executes after successful Repo.update/2", %{user: user} do
      assert capture_log(fn ->
               assert user.full_name == "Bob Dylan"

               assert {:ok, updated_user} =
                        user
                        |> User.changeset(%{last_name: "Marley"})
                        |> Repo.update()

               assert updated_user.full_name == "Bob Marley"
             end) =~ "after update"
    end

    test "executes after successful Repo.update!/2", %{user: user} do
      assert capture_log(fn ->
               assert user.full_name == "Bob Dylan"

               assert updated_user =
                        user
                        |> User.changeset(%{last_name: "Marley"})
                        |> Repo.update!()

               assert updated_user.full_name == "Bob Marley"
             end) =~ "after update"
    end

    test "does not executes after unsuccessful Repo.update/2", %{user: user} do
      refute capture_log(fn ->
               assert {:error, %Ecto.Changeset{}} =
                        user
                        |> User.changeset(%{last_name: nil})
                        |> Repo.update()
             end) =~ "after update"
    end

    test "does not executes after unsuccessful Repo.update!/2", %{user: user} do
      assert_raise Ecto.InvalidChangesetError, fn ->
        assert %Ecto.Changeset{} =
                 user
                 |> User.changeset(%{last_name: ""})
                 |> Repo.update!()
      end
    end

    test "executes after successful Repo.insert_or_update/2 if it updated", %{user: user} do
      assert capture_log(fn ->
               assert {:ok, user} =
                        user
                        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
                        |> Repo.insert_or_update()

               assert user.full_name == "Bob Dylan"
             end) =~ "after update"
    end

    test "executes after successful Repo.insert_or_update!/2 if it updated", %{user: user} do
      assert capture_log(fn ->
               assert user =
                        user
                        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
                        |> Repo.insert_or_update!()

               assert user.full_name == "Bob Dylan"
             end) =~ "after update"
    end

    test "does not executes after unsuccessful Repo.insert_or_update/2 if it updated", %{
      user: user
    } do
      refute capture_log(fn ->
               assert {:error, %Ecto.Changeset{}} =
                        user
                        |> User.changeset(%{last_name: nil})
                        |> Repo.insert_or_update()
             end) =~ "after update"
    end

    test "does not executes after unsuccessful Repo.insert_or_update!/2 if it updated", %{
      user: user
    } do
      assert_raise Ecto.InvalidChangesetError, fn ->
        assert %Ecto.Changeset{} =
                 user
                 |> User.changeset(%{last_name: nil})
                 |> Repo.insert_or_update!()
      end
    end
  end

  describe "after_get/1" do
    setup do
      Logger.configure(level: :error)

      {:ok, user} =
        %User{}
        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
        |> Repo.insert()

      Logger.configure(level: :info)

      {:ok, user: user}
    end

    test "executes after successful Repo.get/2", %{user: user} do
      assert capture_log(fn ->
               assert user = Repo.get(User, user.id)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "executes after successful Repo.get!/2", %{user: user} do
      assert capture_log(fn ->
               assert user = Repo.get!(User, user.id)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.get/2" do
      refute capture_log(fn ->
               assert is_nil(Repo.get(User, 1))
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.get!/2" do
      assert_raise Ecto.NoResultsError, fn -> assert user = Repo.get!(User, 1) end
    end

    test "executes after successful Repo.get_by/2", %{user: user} do
      assert capture_log(fn ->
               assert user = Repo.get_by(User, first_name: user.first_name)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "executes after successful Repo.get_by!/2", %{user: user} do
      assert capture_log(fn ->
               assert user = Repo.get_by!(User, first_name: user.first_name)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.get_by/2" do
      refute capture_log(fn ->
               assert is_nil(Repo.get_by(User, first_name: "Amy"))
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.get_by!/2" do
      assert_raise Ecto.NoResultsError, fn ->
        assert user = Repo.get_by!(User, first_name: "Amy")
      end
    end

    test "executes after successful Repo.one/2", %{user: user} do
      assert capture_log(fn ->
               user_id = user.id
               query = from(u in User, where: u.id == ^user_id)
               assert user = Repo.one(query)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "executes after successful Repo.one!/2", %{user: user} do
      assert capture_log(fn ->
               user_id = user.id
               query = from(u in User, where: u.id == ^user_id)
               assert user = Repo.one!(query)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.one/2" do
      refute capture_log(fn ->
               query = from(u in User, where: u.id == 999)
               assert is_nil(Repo.one(query))
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.one!/2" do
      assert_raise Ecto.NoResultsError, fn ->
        query = from(u in User, where: u.id == 999)
        assert is_nil(Repo.one!(query))
      end
    end

    test "executes after successful Repo.all/2", %{user: user} do
      assert capture_log(fn ->
               user_id = user.id
               query = from(u in User, where: u.id == ^user_id)
               assert [user] = Repo.all(query)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.all/2" do
      refute capture_log(fn ->
               query = from(u in User, where: u.id == 999)
               assert [] = Repo.all(query)
             end) =~ "after get"
    end
  end

  describe "after_delete/1" do
    setup do
      Logger.configure(level: :error)

      {:ok, user} =
        %User{}
        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
        |> Repo.insert()

      Logger.configure(level: :info)

      {:ok, user: user}
    end

    test "executes after successful Repo.delete/2", %{user: user} do
      assert capture_log(fn ->
               assert {:ok, deleted_user} = Repo.delete(user)
               assert deleted_user.full_name == "Bob Dylan"
             end) =~ "after delete"
    end

    test "executes after successful Repo.delete!/2", %{user: user} do
      assert capture_log(fn ->
               assert deleted_user = Repo.delete!(user)
               assert deleted_user.full_name == "Bob Dylan"
             end) =~ "after delete"
    end

    test "does not executes after unsuccessful Repo.delete!/2" do
      assert_raise Ecto.NoPrimaryKeyValueError, fn ->
        assert Repo.delete!(%User{})
      end
    end
  end
end
