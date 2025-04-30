defmodule BotsPlatformWeb.Resolvers.Subscriptions do
  alias BotsPlatform.Subscriptions
  alias BotsPlatform.Accounts

  def subscribe_to_bot(_, %{bot_id: bot_id}, %{context: %{current_user: current_user}}) do
    case Subscriptions.subscribe_user_to_bot(current_user.id, bot_id) do
      {:ok, _} ->
        {:ok, %{success: true, message: "Successfully subscribed to bot"}}

      {:error, changeset} ->
        {:error, message: "Subscription failed", details: format_errors(changeset)}
    end
  end

  def unsubscribe_from_bot(_, %{bot_id: bot_id}, %{context: %{current_user: current_user}}) do
    case Subscriptions.unsubscribe_user_from_bot(current_user.id, bot_id) do
      {:ok, :unsubscribed} ->
        {:ok, %{success: true, message: "Successfully unsubscribed from bot"}}

      {:error, :not_found} ->
        {:error, "Subscription not found"}
    end
  end

  def list_subscribed_bots(_, _, %{context: %{current_user: current_user}}) do
    {:ok, Accounts.get_user_subscribed_bots(current_user.id)}
  end

  def is_subscribed(_, %{bot_id: bot_id}, %{context: %{current_user: current_user}}) do
    {:ok, Subscriptions.is_subscribed?(current_user.id, bot_id)}
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn
        {key, value}, acc when is_binary(value) ->
          String.replace(acc, "%{#{key}}", value)

        {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
