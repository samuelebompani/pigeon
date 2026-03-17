defmodule Pigeon.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :chat, :string, null: false
      add :username, :string, null: false
      add :content, :text, null: false

      timestamps()
    end

    create index(:messages, [:chat])
  end
end
