defmodule Pigeon.Repo do
  use Ecto.Repo,
    otp_app: :pigeon,
    adapter: Ecto.Adapters.Postgres
end
