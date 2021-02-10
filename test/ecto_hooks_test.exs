defmodule Ecto.Repo.HooksTest do
  defmodule Repo do
    use EctoHooks.Repo,
      otp_app: :ecto_hooks,
      adapter: Etso.Adapter
  end

  defmodule BeforeHooksUser do
    use Ecto.Schema
    import Ecto.Changeset

    require Logger

    schema "user" do
      field(:first_name, :string)
      field(:last_name, :string)

      field(:full_name, :string, virtual: true)
    end

    def before_insert(%Ecto.Changeset{} = changeset) do
      Logger.info("before insert")

      changeset
      |> put_change(:last_name, "Before Insert")
    end

    def before_update(%Ecto.Changeset{} = changeset) do
      Logger.info("before update")

      changeset
      |> put_change(:last_name, "Before Update")
    end

    def before_delete(%__MODULE__{} = struct) do
      Logger.info("before delete")
      struct
    end

    def changeset(%__MODULE__{} = user, attrs) do
      user
      |> cast(attrs, [:first_name, :last_name])
      |> validate_required([:first_name, :last_name])
    end
  end

  defmodule AfterHooksUser do
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

  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  import Ecto.Query

  setup do
    {:ok, _} = start_supervised(%{id: __MODULE__, start: {Repo, :start_link, []}})
    :ok
  end

  describe "before_insert/1" do
    setup do
      Logger.configure(level: :info)
    end

    test "executes before successful Repo.insert/2" do
      # Silence before_hook log message
      Logger.configure(level: :error)

      assert {:ok, user} =
               %BeforeHooksUser{}
               |> BeforeHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
               |> Repo.insert()

      assert user.last_name == "Before Insert"
    end

    test "executes before successful Repo.insert!/2" do
      # Silence before_hook log message
      Logger.configure(level: :error)

      assert user =
               %BeforeHooksUser{}
               |> BeforeHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
               |> Repo.insert!()

      assert user.last_name == "Before Insert"
    end

    test "executes before unsuccessful Repo.insert/2" do
      assert capture_log(fn ->
               assert {:error, %Ecto.Changeset{}} =
                        %BeforeHooksUser{}
                        |> BeforeHooksUser.changeset(%{})
                        |> Repo.insert()
             end) =~ "before insert"
    end

    test "executes before unsuccessful Repo.insert!/2" do
      assert capture_log(fn ->
               assert_raise Ecto.InvalidChangesetError, fn ->
                 assert %Ecto.Changeset{} =
                          %BeforeHooksUser{}
                          |> BeforeHooksUser.changeset(%{})
                          |> Repo.insert!()
               end
             end) =~ "before insert"
    end

    test "executes before successful Repo.insert_or_update/2 if it inserted" do
      # Silence before_hook log message
      Logger.configure(level: :error)

      assert {:ok, user} =
               %BeforeHooksUser{}
               |> BeforeHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
               |> Repo.insert_or_update()

      assert user.last_name == "Before Insert"
    end

    test "executes before successful Repo.insert_or_update!/2 if it inserted" do
      # Silence before_hook log message
      Logger.configure(level: :error)

      assert user =
               %BeforeHooksUser{}
               |> BeforeHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
               |> Repo.insert_or_update!()

      assert user.last_name == "Before Insert"
    end

    test "executes before unsuccessful Repo.insert_or_update/2 if it inserted" do
      assert capture_log(fn ->
               assert {:error, %Ecto.Changeset{}} =
                        %BeforeHooksUser{}
                        |> BeforeHooksUser.changeset(%{first_name: "Bob"})
                        |> Repo.insert_or_update()
             end) =~ "before insert"
    end

    test "executes before unsuccessful Repo.insert_or_update!/2 if it inserted" do
      assert capture_log(fn ->
               assert_raise Ecto.InvalidChangesetError, fn ->
                 assert %Ecto.Changeset{} =
                          %BeforeHooksUser{}
                          |> BeforeHooksUser.changeset(%{})
                          |> Repo.insert_or_update!()
               end
             end) =~ "before insert"
    end
  end

  describe "before_update/1" do
    setup do
      Logger.configure(level: :error)

      {:ok, user} =
        %BeforeHooksUser{}
        |> BeforeHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
        |> Repo.insert()

      Logger.configure(level: :info)

      {:ok, user: user}
    end

    test "executes before successful Repo.update/2", %{user: user} do
      # Silence before_hook log message
      Logger.configure(level: :error)

      assert {:ok, updated_user} =
               user
               |> BeforeHooksUser.changeset(%{last_name: "Marley"})
               |> Repo.update()

      assert updated_user.last_name == "Before Update"
    end

    test "executes before successful Repo.update!/2", %{user: user} do
      assert capture_log(fn ->
               user
               |> BeforeHooksUser.changeset(%{last_name: "Marley"})
               |> Repo.update!()
             end) =~ "before update"
    end

    test "executes before unsuccessful Repo.update/2", %{user: user} do
      assert capture_log(fn ->
               assert {:error, %Ecto.Changeset{}} =
                        user
                        |> BeforeHooksUser.changeset(%{last_name: nil})
                        |> Repo.update()
             end) =~ "before update"
    end

    test "executes before unsuccessful Repo.update!/2", %{user: user} do
      assert capture_log(fn ->
               assert_raise Ecto.InvalidChangesetError, fn ->
                 assert %Ecto.Changeset{} =
                          user
                          |> BeforeHooksUser.changeset(%{last_name: ""})
                          |> Repo.update!()
               end
             end) =~ "before update"
    end

    test "executes before successful Repo.insert_or_update/2 if it updated", %{user: user} do
      # Silence before_hook log message
      Logger.configure(level: :error)

      assert {:ok, user} =
               user
               |> BeforeHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
               |> Repo.insert_or_update()

      assert user.last_name == "Before Update"
    end

    test "executes before successful Repo.insert_or_update!/2 if it updated", %{user: user} do
      # Silence before_hook log message
      Logger.configure(level: :error)

      assert user =
               user
               |> BeforeHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
               |> Repo.insert_or_update!()

      assert user.last_name == "Before Update"
    end

    test "executes before unsuccessful Repo.insert_or_update/2 if it updated", %{
      user: user
    } do
      assert capture_log(fn ->
               assert {:error, %Ecto.Changeset{}} =
                        user
                        |> BeforeHooksUser.changeset(%{last_name: nil})
                        |> Repo.insert_or_update()
             end) =~ "before update"
    end

    test "executes before unsuccessful Repo.insert_or_update!/2 if it updated", %{
      user: user
    } do
      assert capture_log(fn ->
               assert_raise Ecto.InvalidChangesetError, fn ->
                 assert %Ecto.Changeset{} =
                          user
                          |> BeforeHooksUser.changeset(%{last_name: nil})
                          |> Repo.insert_or_update!()
               end
             end) =~ "before update"
    end
  end

  describe "before_delete/1" do
    setup do
      Logger.configure(level: :error)

      {:ok, user} =
        %BeforeHooksUser{}
        |> BeforeHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
        |> Repo.insert()

      Logger.configure(level: :info)

      {:ok, user: user}
    end

    test "executes before successful Repo.delete/2", %{user: user} do
      assert capture_log(fn ->
               assert {:ok, deleted_user} = Repo.delete(user)
             end) =~ "before delete"
    end

    test "executes before successful Repo.delete!/2", %{user: user} do
      assert capture_log(fn ->
               assert deleted_user = Repo.delete!(user)
             end) =~ "before delete"
    end

    test "executes before unsuccessful Repo.delete!/2" do
      assert capture_log(fn ->
               assert_raise Ecto.NoPrimaryKeyValueError, fn ->
                 assert Repo.delete!(%BeforeHooksUser{})
               end
             end) =~ "before delete"
    end
  end

  describe "after_insert/1" do
    test "executes before successful Repo.insert/2" do
      assert capture_log(fn ->
               assert {:ok, user} =
                        %AfterHooksUser{}
                        |> AfterHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
                        |> Repo.insert()

               assert user.full_name == "Bob Dylan"
             end) =~ "after insert"
    end

    test "executes before successful Repo.insert!/2" do
      assert capture_log(fn ->
               assert user =
                        %AfterHooksUser{}
                        |> AfterHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
                        |> Repo.insert!()

               assert user.full_name == "Bob Dylan"
             end) =~ "after insert"
    end

    test "does not executes before unsuccessful Repo.insert/2" do
      refute capture_log(fn ->
               assert {:error, %Ecto.Changeset{}} =
                        %AfterHooksUser{}
                        |> AfterHooksUser.changeset(%{})
                        |> Repo.insert()
             end) =~ "after insert"
    end

    test "does not executes before unsuccessful Repo.insert!/2" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        assert %Ecto.Changeset{} =
                 %AfterHooksUser{}
                 |> AfterHooksUser.changeset(%{})
                 |> Repo.insert!()
      end
    end

    test "executes before successful Repo.insert_or_update/2 if it inserted" do
      assert capture_log(fn ->
               assert {:ok, user} =
                        %AfterHooksUser{}
                        |> AfterHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
                        |> Repo.insert_or_update()

               assert user.full_name == "Bob Dylan"
             end) =~ "after insert"
    end

    test "executes before successful Repo.insert_or_update!/2 if it inserted" do
      assert capture_log(fn ->
               assert user =
                        %AfterHooksUser{}
                        |> AfterHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
                        |> Repo.insert_or_update!()

               assert user.full_name == "Bob Dylan"
             end) =~ "after insert"
    end

    test "does not executes before unsuccessful Repo.insert_or_update/2 if it inserted" do
      refute capture_log(fn ->
               assert {:error, %Ecto.Changeset{}} =
                        %AfterHooksUser{}
                        |> AfterHooksUser.changeset(%{first_name: "Bob"})
                        |> Repo.insert_or_update()
             end) =~ "after insert"
    end

    test "does not executes before unsuccessful Repo.insert_or_update!/2 if it inserted" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        assert %Ecto.Changeset{} =
                 %AfterHooksUser{}
                 |> AfterHooksUser.changeset(%{})
                 |> Repo.insert_or_update!()
      end
    end
  end

  describe "after_update/1" do
    setup do
      Logger.configure(level: :error)

      {:ok, user} =
        %AfterHooksUser{}
        |> AfterHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
        |> Repo.insert()

      Logger.configure(level: :info)

      {:ok, user: user}
    end

    test "executes after successful Repo.update/2", %{user: user} do
      assert capture_log(fn ->
               assert user.full_name == "Bob Dylan"

               assert {:ok, updated_user} =
                        user
                        |> AfterHooksUser.changeset(%{last_name: "Marley"})
                        |> Repo.update()

               assert updated_user.full_name == "Bob Marley"
             end) =~ "after update"
    end

    test "executes after successful Repo.update!/2", %{user: user} do
      assert capture_log(fn ->
               assert user.full_name == "Bob Dylan"

               assert updated_user =
                        user
                        |> AfterHooksUser.changeset(%{last_name: "Marley"})
                        |> Repo.update!()

               assert updated_user.full_name == "Bob Marley"
             end) =~ "after update"
    end

    test "does not executes after unsuccessful Repo.update/2", %{user: user} do
      refute capture_log(fn ->
               assert {:error, %Ecto.Changeset{}} =
                        user
                        |> AfterHooksUser.changeset(%{last_name: nil})
                        |> Repo.update()
             end) =~ "after update"
    end

    test "does not executes after unsuccessful Repo.update!/2", %{user: user} do
      assert_raise Ecto.InvalidChangesetError, fn ->
        assert %Ecto.Changeset{} =
                 user
                 |> AfterHooksUser.changeset(%{last_name: ""})
                 |> Repo.update!()
      end
    end

    test "executes after successful Repo.insert_or_update/2 if it updated", %{user: user} do
      assert capture_log(fn ->
               assert {:ok, user} =
                        user
                        |> AfterHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
                        |> Repo.insert_or_update()

               assert user.full_name == "Bob Dylan"
             end) =~ "after update"
    end

    test "executes after successful Repo.insert_or_update!/2 if it updated", %{user: user} do
      assert capture_log(fn ->
               assert user =
                        user
                        |> AfterHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
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
                        |> AfterHooksUser.changeset(%{last_name: nil})
                        |> Repo.insert_or_update()
             end) =~ "after update"
    end

    test "does not executes after unsuccessful Repo.insert_or_update!/2 if it updated", %{
      user: user
    } do
      assert_raise Ecto.InvalidChangesetError, fn ->
        assert %Ecto.Changeset{} =
                 user
                 |> AfterHooksUser.changeset(%{last_name: nil})
                 |> Repo.insert_or_update!()
      end
    end
  end

  describe "after_get/1" do
    setup do
      Logger.configure(level: :error)

      {:ok, user} =
        %AfterHooksUser{}
        |> AfterHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
        |> Repo.insert()

      Logger.configure(level: :info)

      {:ok, user: user}
    end

    test "executes after successful Repo.get/2", %{user: user} do
      assert capture_log(fn ->
               assert user = Repo.get(AfterHooksUser, user.id)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "executes after successful Repo.get!/2", %{user: user} do
      assert capture_log(fn ->
               assert user = Repo.get!(AfterHooksUser, user.id)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.get/2" do
      refute capture_log(fn ->
               assert is_nil(Repo.get(AfterHooksUser, 1))
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.get!/2" do
      assert_raise Ecto.NoResultsError, fn -> assert user = Repo.get!(AfterHooksUser, 1) end
    end

    test "executes after successful Repo.get_by/2", %{user: user} do
      assert capture_log(fn ->
               assert user = Repo.get_by(AfterHooksUser, first_name: user.first_name)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "executes after successful Repo.get_by!/2", %{user: user} do
      assert capture_log(fn ->
               assert user = Repo.get_by!(AfterHooksUser, first_name: user.first_name)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.get_by/2" do
      refute capture_log(fn ->
               assert is_nil(Repo.get_by(AfterHooksUser, first_name: "Amy"))
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.get_by!/2" do
      assert_raise Ecto.NoResultsError, fn ->
        assert user = Repo.get_by!(AfterHooksUser, first_name: "Amy")
      end
    end

    test "executes after successful Repo.one/2", %{user: user} do
      assert capture_log(fn ->
               user_id = user.id
               query = from(u in AfterHooksUser, where: u.id == ^user_id)
               assert user = Repo.one(query)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "executes after successful Repo.one!/2", %{user: user} do
      assert capture_log(fn ->
               user_id = user.id
               query = from(u in AfterHooksUser, where: u.id == ^user_id)
               assert user = Repo.one!(query)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.one/2" do
      refute capture_log(fn ->
               query = from(u in AfterHooksUser, where: u.id == 999)
               assert is_nil(Repo.one(query))
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.one!/2" do
      assert_raise Ecto.NoResultsError, fn ->
        query = from(u in AfterHooksUser, where: u.id == 999)
        assert is_nil(Repo.one!(query))
      end
    end

    test "executes after successful Repo.all/2", %{user: user} do
      assert capture_log(fn ->
               user_id = user.id
               query = from(u in AfterHooksUser, where: u.id == ^user_id)
               assert [user] = Repo.all(query)
               assert user.full_name == "Bob Dylan"
             end) =~ "after get"
    end

    test "does not executes after unsuccessful Repo.all/2" do
      refute capture_log(fn ->
               query = from(u in AfterHooksUser, where: u.id == 999)
               assert [] = Repo.all(query)
             end) =~ "after get"
    end
  end

  describe "after_delete/1" do
    setup do
      Logger.configure(level: :error)

      {:ok, user} =
        %AfterHooksUser{}
        |> AfterHooksUser.changeset(%{first_name: "Bob", last_name: "Dylan"})
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
        assert Repo.delete!(%AfterHooksUser{})
      end
    end
  end
end
