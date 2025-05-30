defmodule BotsPlatformWeb.MessageChannel do
  use Phoenix.Channel

  # Исправляем шаблон топика
  def join("messages:" <> rest, _params, socket) do
    case String.split(rest, ":") do
      [bot_id, chat_id] ->
        {:ok, assign(socket, :bot_id, bot_id) |> assign(:chat_id, chat_id)}
      _ ->
        {:error, %{reason: "invalid topic format"}}
    end
  end

  def handle_in("new_message", payload, socket) do
    broadcast(socket, "new_message", payload)
    {:noreply, socket}
  end
end
