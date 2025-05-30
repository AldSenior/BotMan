defmodule BotsPlatformWeb.Router do
  use BotsPlatformWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
    # Если вы используете CORS
    plug(CORSPlug, origin: ["http://localhost:3000"])
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  # Публичные маршруты без аутентификации
  scope "/api" do
    pipe_through(:api)

    # GraphQL endpoint
    forward("/graphql", Absinthe.Plug, schema: BotsPlatformWeb.Schema)

    # GraphiQL UI для разработки
    forward("/graphiql", Absinthe.Plug.GraphiQL,
      schema: BotsPlatformWeb.Schema,
      socket: BotsPlatformWeb.UserSocket,
      interface: :playground
    )

    # REST-эндпоинт для загрузки файлов
    post("/upload", BotsPlatformWeb.FileController, :upload)
  end

  scope "/" do
    pipe_through(:browser)
    get("/uploads/*path", BotsPlatformWeb.UploadController, :serve)
  end
end
