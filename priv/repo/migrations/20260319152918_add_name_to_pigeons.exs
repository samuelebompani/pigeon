defmodule Pigeon.Repo.Migrations.AddNameToPigeons do
  use Ecto.Migration

  def change do
    alter table(:pigeons) do
      add :name, :string
    end
  end
end
