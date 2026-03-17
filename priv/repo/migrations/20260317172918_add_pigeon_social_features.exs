defmodule Pigeon.Repo.Migrations.AddPigeonSocialFeatures do
  use Ecto.Migration

  def change do
    alter table(:pigeons) do
      add :personality, :string
      add :owners, {:array, :string}
      add :status, :string
    end
  end
end
