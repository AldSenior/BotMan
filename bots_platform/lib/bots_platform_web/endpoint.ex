defmodule BotsPlatformWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :bots_platform
  use Absinthe.Phoenix.Endpoint

  @session_options [
    store: :cookie,
    key: "_bots_platform_key",
    signing_salt: "dgej5cOf",
    same_site: "Lax",
    extra: "SameSite=Lax"
  ]

  socket("/socket", BotsPlatformWeb.UserSocket,
    websocket: true,
    longpoll: false
  )

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]
  )

  plug(Plug.Static,
    at: "/",
    from: :bots_platform,
    gzip: false,
    only: BotsPlatformWeb.static_paths()
  )

  if code_reloading? do
    plug(Phoenix.CodeReloader)
    plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :bots_platform)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    length: 100_000_000
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)

  plug(BotsPlatformWeb.Router)

  # Custom error handling
  # plug Plug.ErrorHandler
  # defp handle_errors(conn, %{reason: reason, stack: _stack}) do
  #   conn
  #   |> put_resp_content_type("application/json")
  #   |> send_resp(500, Jason.encode!({errors: [{
  #     message: "Internal server error",
  #     details: inspect(reason)
  #   ]}))
  # end
end
