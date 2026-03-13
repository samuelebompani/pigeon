defmodule Pigeon.Presence do
  use Phoenix.Presence,
    otp_app: :pigeon,
    pubsub_server: Pigeon.PubSub
end
