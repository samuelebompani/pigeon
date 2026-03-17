defmodule Pigeon.Repo.Migrations.CreatePigeons do
  use Ecto.Migration

  def change do
    create table(:pigeons) do
      add :chat, :string, null: false
      add :hunger, :integer, default: 50

      timestamps()
    end

    create unique_index(:pigeons, [:chat])
  end
end
