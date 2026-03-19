defmodule PigeonWeb.Router do
  use PigeonWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PigeonWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PigeonWeb do
    pipe_through :browser

    live "/login", LoginLive
    live "/register", RegisterLive
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete
    post "/register", RegisterController, :create

    # Everything below requires a session
    live_session :authenticated,
      on_mount: {PigeonWeb.Auth, :require_authenticated} do
      live "/", HomeLive
      live "/chat/:user", ChatLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", PigeonWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:pigeon, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: PigeonWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
