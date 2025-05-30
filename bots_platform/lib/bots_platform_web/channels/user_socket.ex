defmodule BotsPlatformWeb.UserSocket do
  use Phoenix.Socket
  use Absinthe.Phoenix.Socket, schema: BotsPlatformWeb.Schema

  # Каналы для разных типов сообщений
  channel("bot:*", BotsPlatformWeb.BotChannel)

  @impl true
  def connect(params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil

  channel("bot:*", BotsPlatformWeb.BotChannel)

  def connect(%{"token" => token}, socket, _connect_info) do
    {:ok, assign(socket, :token, token)}
  end

  def id(_socket), do: nil
end
