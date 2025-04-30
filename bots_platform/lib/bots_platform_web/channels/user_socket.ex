defmodule BotsPlatformWeb.UserSocket do
  use Phoenix.Socket
  use Absinthe.Phoenix.Socket, schema: BotsPlatformWeb.Schema

  # Каналы для разных типов сообщений
  channel("bot:*", BotsPlatformWeb.BotChannel)

  @impl true
  def connect(params, socket, _connect_info) do
    # Тут вся логика аутентификации...
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
