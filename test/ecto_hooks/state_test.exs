defmodule EctoHooks.StateTest do
  use ExUnit.Case, async: false

  alias EctoHooks.State

  describe "disable_hooks/1" do
    test "when already enabled, disables hooks such that `hooks_enabled?/0` returns false" do
      assert State.hooks_enabled?()
      assert :ok = State.disable_hooks(global: false)
      refute State.hooks_enabled?()
    end

    test "disabling hooks multiple times is a noop" do
      assert State.hooks_enabled?()
      assert :ok = State.disable_hooks(global: false)
      assert :ok = State.disable_hooks(global: false)
      refute State.hooks_enabled?()
    end
  end

  describe "enable_hooks/1" do
    test "when already enabled, disables hooks such that `hooks_enabled?/0` returns false" do
      assert :ok = State.disable_hooks(global: false)
      refute State.hooks_enabled?()
      assert :ok = State.enable_hooks(global: false)
      assert State.hooks_enabled?()
    end

    test "enabling hooks multiple times is a noop" do
      assert State.hooks_enabled?()
      assert :ok = State.enable_hooks(global: false)
      assert :ok = State.enable_hooks(global: false)
      assert State.hooks_enabled?()
    end
  end

  describe "hooks_enabled?/0" do
    test "returns true if hooks enabled" do
      assert :ok = State.enable_hooks(global: false)
      assert State.hooks_enabled?()
    end

    test "returns false if hooks disabled" do
      assert :ok = State.disable_hooks(global: false)
      refute State.hooks_enabled?()
    end
  end

  describe "acquire_hook/0" do
    test "increments ref count" do
      refute State.in_hook?()
      assert 0 = State.hooks_ref_count()

      assert State.acquire_hook()
      assert State.in_hook?()
      assert 1 = State.hooks_ref_count()

      assert State.acquire_hook()
      assert State.in_hook?()
      assert 2 = State.hooks_ref_count()
    end
  end

  describe "release_hook/0" do
    test "increments ref count" do
      refute State.in_hook?()
      assert 0 = State.hooks_ref_count()

      assert State.acquire_hook()
      assert State.in_hook?()
      assert 1 = State.hooks_ref_count()

      assert State.acquire_hook()
      assert State.in_hook?()
      assert 2 = State.hooks_ref_count()

      assert State.release_hook()
      assert State.in_hook?()
      assert 1 = State.hooks_ref_count()

      assert State.release_hook()
      refute State.in_hook?()
      assert 0 = State.hooks_ref_count()
    end
  end

  describe "hooks_ref_count/0" do
    test "returns current nesting for hooks" do
      refute State.in_hook?()
      assert 0 = State.hooks_ref_count()

      assert State.acquire_hook()
      assert State.in_hook?()
      assert 1 = State.hooks_ref_count()

      assert State.release_hook()
      refute State.in_hook?()
      assert 0 = State.hooks_ref_count()
    end
  end

  describe "in_hook?/0" do
    test "returns false when no hooks have been acquired" do
      refute State.in_hook?()
    end

    test "returns true when hooks have been acquired" do
      assert State.acquire_hook()
      assert State.in_hook?()
    end
  end
end
