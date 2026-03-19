defmodule Pigeon.Repo.Migrations.AddPigeonRequestedBy do
  use Ecto.Migration

  def change do
    alter table(:pigeons) do
      add :requested_by, :string
    end
  end
end
