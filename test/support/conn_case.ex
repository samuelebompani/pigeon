defmodule PigeonWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use PigeonWeb, :verified_routes
      import Plug.Conn
      import Phoenix.ConnTest
      import PigeonWeb.ConnCase
      alias Pigeon.Repo

      @endpoint PigeonWeb.Endpoint
    end
  end

  setup tags do
    Pigeon.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
