defmodule Pigeon.AccountsTest do
  use Pigeon.DataCase, async: true

  alias Pigeon.Accounts
  alias Pigeon.Accounts.User

  describe "register/1" do
    test "creates a user with valid attrs" do
      assert {:ok, %User{} = user} = Accounts.register(%{username: "alice", password: "secret"})
      assert user.username == "alice"
      assert user.password_hash != "secret"
    end

    test "hashes the password" do
      {:ok, user} = Accounts.register(%{username: "alice", password: "secret"})
      assert Bcrypt.verify_pass("secret", user.password_hash)
    end

    test "rejects duplicate username" do
      Accounts.register(%{username: "alice", password: "secret"})
      assert {:error, changeset} = Accounts.register(%{username: "alice", password: "other"})
      assert %{username: ["has already been taken"]} = errors_on(changeset)
    end

    test "rejects too-short username" do
      assert {:error, changeset} = Accounts.register(%{username: "a", password: "secret"})
      assert %{username: [_]} = errors_on(changeset)
    end

    test "rejects too-short password" do
      assert {:error, changeset} = Accounts.register(%{username: "alice", password: "abc"})
      assert %{password: [_]} = errors_on(changeset)
    end

    test "rejects missing fields" do
      assert {:error, changeset} = Accounts.register(%{})
      assert %{username: [_], password: [_]} = errors_on(changeset)
    end
  end

  describe "authenticate/2" do
    setup do
      {:ok, user} = Accounts.register(%{username: "bob", password: "hunter2"})
      %{user: user}
    end

    test "returns user on correct credentials", %{user: user} do
      assert {:ok, authenticated} = Accounts.authenticate("bob", "hunter2")
      assert authenticated.id == user.id
    end

    test "returns error on wrong password" do
      assert {:error, :bad_password} = Accounts.authenticate("bob", "wrong")
    end

    test "returns error on unknown username" do
      assert {:error, :not_found} = Accounts.authenticate("nobody", "hunter2")
    end
  end
end
