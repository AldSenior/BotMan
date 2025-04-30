defmodule BotsPlatformWeb.Resolvers.Messages do
  alias BotsPlatform.Messages
  alias BotsPlatform.Bots
  alias BotsPlatform.Auth.Guardian
  require Logger

   defp authenticate_token(token) when is_binary(token) do
     token = case String.split(token, "Bearer ") do
       [token] -> token
       [_, token] -> token
     end

     case Guardian.decode_and_verify(token) do
       {:ok, claims} -> Guardian.resource_from_claims(claims)
       error -> error
     end
   end

   def list_messages(_, %{bot_id: bot_id, token: token}, _) when is_binary(token) do
     with {:ok, user} <- authenticate_token(token),
          bot when not is_nil(bot) <- Bots.get_bot(bot_id) do
       cond do
         user.is_admin || bot.user_id == user.id ->
           {:ok, Messages.list_bot_messages(bot_id)}
         true ->
           {:error, "Нет доступа к сообщениям этого бота"}
       end
     else
       nil -> {:error, "Бот не найден"}
       error -> error
     end
   end

   def create_message(_, %{input: params, token: token}, _) when is_binary(token) do
     with {:ok, user} <- authenticate_token(token),
          bot when not is_nil(bot) <- Bots.get_bot(params.bot_id) do
       cond do
         user.is_admin || bot.user_id == user.id ->
           case Messages.create_message(params) do
             {:ok, message} -> {:ok, message}
             {:error, changeset} -> {:error, format_errors(changeset)}
           end
         true ->
           {:error, "Нет доступа к этому боту"}
       end
     else
       nil -> {:error, "Бот не найден"}
       error -> error
     end
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
