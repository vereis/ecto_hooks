defmodule EctoHooks.RepoTest do
  use ExUnit.Case, async: false

  alias EctoHooks.Delta

  def clear_hooks do
    hooks = [
      :before_insert,
      :before_update,
      :before_delete,
      :after_get,
      :after_insert,
      :after_update,
      :after_delete
    ]

    for hook <- hooks, do: put_hook(hook, nil)
    :ok
  end

  def put_hook(hook_name, function) do
    Process.put({__MODULE__, hook_name}, function)
    :ok
  end

  def get_hook(hook_name) do
    case Atom.to_string(hook_name) do
      "after_" <> _rest ->
        Process.get({__MODULE__, hook_name}) || fn result, _delta -> result end

      _otherwise ->
        Process.get({__MODULE__, hook_name}) || fn changeset -> changeset end
    end
  end

  def is_bang?(repo_callback) do
    repo_callback
    |> Atom.to_string()
    |> String.ends_with?("!")
  end

  def unwrap({_term, x}), do: x
  def unwrap([x | _xs]), do: x
  def unwrap([]), do: nil
  def unwrap(x), do: x

  defmodule Repo do
    use EctoHooks.Repo,
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

    def before_insert(%Ecto.Changeset{} = changeset),
      do: EctoHooks.RepoTest.get_hook(:before_insert).(changeset)

    def before_update(%Ecto.Changeset{} = changeset),
      do: EctoHooks.RepoTest.get_hook(:before_update).(changeset)

    def before_delete(%__MODULE__{} = schema),
      do: EctoHooks.RepoTest.get_hook(:before_delete).(schema)

    def after_get(%__MODULE__{} = schema, %Delta{} = delta),
      do: EctoHooks.RepoTest.get_hook(:after_get).(schema, delta)

    def after_insert(%__MODULE__{} = schema, %Delta{} = delta),
      do: EctoHooks.RepoTest.get_hook(:after_insert).(schema, delta)

    def after_update(%__MODULE__{} = schema, %Delta{} = delta),
      do: EctoHooks.RepoTest.get_hook(:after_update).(schema, delta)

    def after_delete(%__MODULE__{} = schema, %Delta{} = delta),
      do: EctoHooks.RepoTest.get_hook(:after_delete).(schema, delta)

    def changeset(%__MODULE__{} = user, attrs) do
      user
      |> cast(attrs, [:first_name, :last_name])
      |> validate_required([:first_name, :last_name])
    end
  end

  setup do
    {:ok, _repo} = start_supervised(%{id: __MODULE__, start: {Repo, :start_link, []}})
    :ok = clear_hooks()
  end

  describe "before_insert/2" do
    for repo_callback <- [:insert, :insert_or_update, :insert!, :insert_or_update!] do
      good_test_name = "executes before successful Repo.#{repo_callback}/1"
      bad_test_name = "executes before unsuccessful Repo.#{repo_callback}/1"

      test good_test_name do
        put_hook(:before_insert, fn %Ecto.Changeset{} = changeset ->
          Ecto.Changeset.force_change(changeset, :last_name, "Marley")
        end)

        user =
          %User{}
          |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
          |> Repo.unquote(repo_callback)

        assert %User{first_name: "Bob", last_name: "Marley"} = unwrap(user)
      end

      test bad_test_name do
        expected_message = Ecto.UUID.generate()

        put_hook(:before_insert, fn %Ecto.Changeset{} ->
          send(self(), expected_message)
        end)

        try do
          %User{}
          |> User.changeset(%{})
          |> Repo.unquote(repo_callback)
        rescue
          _e ->
            :noop
        after
          assert_received(expected_message)
        end
      end
    end
  end

  describe "before_update/2" do
    setup do
      user =
        %User{}
        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
        |> Repo.insert!()

      {:ok, user: user}
    end

    for repo_callback <- [:update, :insert_or_update, :update!, :insert_or_update!] do
      good_test_name = "executes before successful Repo.#{repo_callback}/1"
      bad_test_name = "executes before unsuccessful Repo.#{repo_callback}/1"

      test good_test_name, ctx do
        put_hook(:before_update, fn %Ecto.Changeset{} = changeset ->
          Ecto.Changeset.force_change(changeset, :last_name, "Eager")
        end)

        user =
          ctx.user
          |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
          |> Repo.unquote(repo_callback)

        assert %User{first_name: "Bob", last_name: "Eager"} = unwrap(user)
      end

      test bad_test_name, ctx do
        expected_message = Ecto.UUID.generate()

        put_hook(:before_update, fn %Ecto.Changeset{} ->
          send(self(), expected_message)
        end)

        try do
          ctx.user
          |> User.changeset(%{})
          |> Repo.unquote(repo_callback)
        rescue
          _e ->
            :noop
        after
          assert_received(expected_message)
        end
      end
    end
  end

  describe "before_delete/2" do
    setup do
      user =
        %User{}
        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
        |> Repo.insert!()

      {:ok, user: user}
    end

    for repo_callback <- [:delete, :delete!] do
      good_test_name = "executes before successful Repo.#{repo_callback}/1"
      bad_test_name = "executes before unsuccessful Repo.#{repo_callback}/1"

      test good_test_name, ctx do
        expected_message = Ecto.UUID.generate()

        put_hook(:before_delete, fn schema ->
          send(self(), expected_message)
          schema
        end)

        assert %User{} =
                 ctx.user
                 |> Repo.unquote(repo_callback)
                 |> unwrap()

        assert_received(expected_message)
      end

      test bad_test_name do
        expected_message = Ecto.UUID.generate()

        put_hook(:before_delete, fn schema ->
          send(self(), expected_message)
          schema
        end)

        assert_raise Ecto.NoPrimaryKeyValueError, fn ->
          %User{}
          |> Repo.unquote(repo_callback)
          |> unwrap()
        end

        assert_received(expected_message)
      end
    end
  end

  describe "after_get/2" do
    setup do
      user =
        %User{}
        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
        |> Repo.insert!()

      {:ok, user: user}
    end

    for repo_callback <- [:reload, :reload!] do
      singular_test_name = "executes after successful Repo.#{repo_callback}/1 given struct"
      plural_test_name = "executes after successful Repo.#{repo_callback}/1 given list"

      test singular_test_name, ctx do
        put_hook(:after_get, fn %User{full_name: nil} = user, %Delta{} = delta ->
          assert delta.hook == :after_get
          assert delta.repo_callback == unquote(repo_callback)
          assert delta.source == delta.record
          %{user | full_name: user.first_name <> " " <> user.last_name}
        end)

        response = Repo.unquote(repo_callback)(ctx.user)
        assert %User{full_name: "Bob Dylan"} = unwrap(response)
      end

      test plural_test_name, ctx do
        put_hook(:after_get, fn %User{full_name: nil} = user, %Delta{} = delta ->
          assert delta.hook == :after_get
          assert delta.repo_callback == unquote(repo_callback)
          assert delta.source == delta.record

          %{user | full_name: user.first_name <> " " <> user.last_name}
        end)

        [response] = Repo.unquote(repo_callback)([ctx.user])
        assert %User{full_name: "Bob Dylan"} = unwrap(response)
      end
    end

    for repo_callback <- [:all, :one, :one!] do
      test_name = "executes after successful Repo.#{repo_callback}/1"

      test test_name do
        put_hook(:after_get, fn %User{full_name: nil} = user, %Delta{} = delta ->
          assert delta.hook == :after_get
          assert delta.repo_callback == unquote(repo_callback)
          assert delta.source == delta.queryable

          %{user | full_name: user.first_name <> " " <> user.last_name}
        end)

        response = Repo.unquote(repo_callback)(User)

        assert %User{full_name: "Bob Dylan"} = unwrap(response)
      end
    end

    for repo_callback <- [:get, :get!] do
      good_test_name = "executes after successful Repo.#{repo_callback}/1"
      bad_test_name = "does not execute after unsuccessful Repo.#{repo_callback}/1"

      test good_test_name, ctx do
        put_hook(:after_get, fn %User{full_name: nil} = user, %Delta{} = delta ->
          assert delta.hook == :after_get
          assert delta.repo_callback == unquote(repo_callback)
          assert delta.source == delta.queryable

          %{user | full_name: user.first_name <> " " <> user.last_name}
        end)

        response = Repo.unquote(repo_callback)(User, ctx.user.id)

        assert %User{full_name: "Bob Dylan"} = unwrap(response)
      end

      test bad_test_name do
        put_hook(:after_get, fn %User{}, %Delta{} ->
          flunk("This hook should not have been called!")
        end)

        assert is_nil(Repo.unquote(repo_callback)(User, 1234))
      rescue
        e in Ecto.NoResultsError ->
          unless is_bang?(unquote(repo_callback)), do: reraise(e, __STACKTRACE__)
      end
    end

    for repo_callback <- [:get_by, :get_by!] do
      good_test_name = "executes after successful Repo.#{repo_callback}/1"
      bad_test_name = "does not execute after unsuccessful Repo.#{repo_callback}/1"

      test good_test_name, ctx do
        put_hook(:after_get, fn %User{full_name: nil} = user, %Delta{} = delta ->
          assert delta.hook == :after_get
          assert delta.repo_callback == unquote(repo_callback)
          assert delta.source == delta.queryable

          %{user | full_name: user.first_name <> " " <> user.last_name}
        end)

        response = Repo.unquote(repo_callback)(User, id: ctx.user.id)

        assert %User{full_name: "Bob Dylan"} = unwrap(response)
      end

      test bad_test_name do
        put_hook(:after_get, fn %User{}, %Delta{} ->
          flunk("This hook should not have been called!")
        end)

        assert is_nil(Repo.unquote(repo_callback)(User, id: 1234))
      rescue
        e in Ecto.NoResultsError ->
          unless is_bang?(unquote(repo_callback)), do: reraise(e, __STACKTRACE__)
      end
    end
  end

  describe "after_insert/2" do
    for repo_callback <- [:insert, :insert_or_update, :insert!, :insert_or_update!] do
      good_test_name = "executes after successful Repo.#{repo_callback}/1"
      bad_test_name = "does not execute after unsuccessful Repo.#{repo_callback}/1"

      test good_test_name do
        put_hook(:after_insert, fn %User{full_name: nil} = user, %Delta{} = delta ->
          assert delta.hook == :after_insert
          assert delta.repo_callback == unquote(repo_callback)
          assert delta.source == delta.changeset
          assert %Ecto.Changeset{valid?: true} = delta.changeset

          %{user | full_name: user.first_name <> " " <> user.last_name}
        end)

        response =
          %User{}
          |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
          |> Repo.unquote(repo_callback)

        assert %User{full_name: "Bob Dylan"} = unwrap(response)
      end

      test bad_test_name do
        put_hook(:after_insert, fn %User{full_name: nil}, %Delta{} ->
          flunk("This hook should not have been called!")
        end)

        response =
          %User{}
          |> User.changeset(%{})
          |> Repo.unquote(repo_callback)

        assert %Ecto.Changeset{errors: _errors} = unwrap(response)
      rescue
        e in Ecto.InvalidChangesetError ->
          unless is_bang?(unquote(repo_callback)), do: reraise(e, __STACKTRACE__)
      end
    end
  end

  describe "after_update/2" do
    setup do
      user =
        %User{}
        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
        |> Repo.insert!()

      {:ok, user: user}
    end

    for repo_callback <- [:update, :insert_or_update, :update!, :insert_or_update!] do
      good_test_name = "executes after successful Repo.#{repo_callback}/1"
      bad_test_name = "does not execute after unsuccessful Repo.#{repo_callback}/1"

      test good_test_name, %{user: seeded_user} do
        put_hook(:after_update, fn user, %Delta{} = delta ->
          assert seeded_user.id == user.id
          assert delta.hook == :after_update
          assert delta.repo_callback == unquote(repo_callback)
          assert delta.source == delta.changeset
          assert %Ecto.Changeset{valid?: true} = delta.changeset

          %{user | full_name: user.first_name <> " " <> user.last_name}
        end)

        response =
          seeded_user
          |> User.changeset(%{last_name: "Marley"})
          |> Repo.unquote(repo_callback)

        assert %User{full_name: "Bob Marley"} = unwrap(response)
      end

      test bad_test_name do
        put_hook(:after_update, fn %User{full_name: nil}, %Delta{} ->
          flunk("This hook should not have been called!")
        end)

        response =
          %User{}
          |> User.changeset(%{})
          |> Repo.unquote(repo_callback)

        assert %Ecto.Changeset{errors: _errors} = unwrap(response)
      rescue
        e in Ecto.InvalidChangesetError ->
          unless is_bang?(unquote(repo_callback)), do: reraise(e, __STACKTRACE__)
      end
    end
  end

  describe "after_delete/2" do
    setup do
      user =
        %User{}
        |> User.changeset(%{first_name: "Bob", last_name: "Dylan"})
        |> Repo.insert!()

      {:ok, user: user}
    end

    for repo_callback <- [:delete, :delete!] do
      good_test_name = "executes after successful Repo.#{repo_callback}/1"
      bad_test_name = "does not execute after unsuccessful Repo.#{repo_callback}/1"

      test good_test_name, %{user: seeded_user} do
        put_hook(:after_delete, fn user, %Delta{} = delta ->
          assert seeded_user.id == user.id
          assert delta.hook == :after_delete
          assert delta.repo_callback == unquote(repo_callback)
          assert delta.source == delta.record

          %{user | full_name: user.first_name <> " " <> user.last_name}
        end)

        # Deleting records still returns them, plus any changes a hook might
        # have made, so assert the database as well.
        assert [^seeded_user] = Repo.all(User)

        response =
          seeded_user
          |> Repo.unquote(repo_callback)

        assert %User{full_name: "Bob Dylan"} = unwrap(response)
        assert [] = Repo.all(User)
      end

      test bad_test_name do
        put_hook(:after_update, fn %User{full_name: nil}, %Delta{} ->
          flunk("This hook should not have been called!")
        end)

        assert_raise Ecto.NoPrimaryKeyValueError, fn ->
          Repo.unquote(repo_callback)(%User{})
        end
      end
    end
  end
end
