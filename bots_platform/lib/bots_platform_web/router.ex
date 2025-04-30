defmodule BotsPlatformWeb.Router do
  use BotsPlatformWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
    # Если вы используете CORS
    # plug CORSPlug, origin: "*"
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
  end

  # Остальные маршруты...
end
