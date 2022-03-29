defmodule EctoHooks.DeltaTest do
  use ExUnit.Case, async: false

  alias EctoHooks.Delta

  defmodule User do
    use Ecto.Schema

    schema "user" do
      field(:first_name, :string)
      field(:last_name, :string)
    end
  end

  describe "new!/3" do
    for hook <- Delta.hooks(),
        repo_callback <- Delta.repo_callbacks() do
      test "given callback: `#{repo_callback}` and hook: `#{hook}`, persists accordingly" do
        assert %Delta{} = delta = Delta.new!(unquote(repo_callback), unquote(hook), Test)

        assert delta.repo_callback == unquote(repo_callback)
        assert delta.hook == unquote(hook)
        assert delta.source == Test

        assert is_nil(delta.changeset)
        assert is_nil(delta.queryable)
        assert is_nil(delta.record)
      end
    end

    test "raises given invalid callback" do
      assert_raise FunctionClauseError, fn ->
        Delta.new!(:random, Enum.random(Delta.hooks()), Test)
      end
    end

    test "raises given invalid hook" do
      assert_raise FunctionClauseError, fn ->
        Delta.new!(Enum.random(Delta.repo_callbacks()), :random, Test)
      end
    end

    test "given changeset, sets changeset field" do
      changeset = %Ecto.Changeset{}

      assert %Delta{changeset: ^changeset, source: ^changeset} =
               Delta.new!(:insert, :after_insert, changeset)
    end

    test "given queryable, sets queryable field" do
      queryable = %Ecto.Query{}

      assert %Delta{queryable: ^queryable, source: ^queryable} =
               Delta.new!(:insert, :after_insert, queryable)
    end

    test "given schema struct, sets record field" do
      schema_struct = %User{}

      assert %Delta{record: ^schema_struct, source: ^schema_struct} =
               Delta.new!(:insert, :after_insert, schema_struct)
    end
  end
end
