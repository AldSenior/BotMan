defmodule BotsPlatformWeb.Resolvers.Accounts do
  alias BotsPlatform.Accounts
  alias BotsPlatform.Auth.Guardian
  require Logger

  @doc """
  Регистрация нового пользователя
  """
  def register_user(_, %{input: user_params}, _) do
    with {:ok, user} <- Accounts.create_user(user_params),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user) do
      {:ok, %{token: token, user: user}}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("User registration failed: #{inspect(changeset.errors)}")
        {:error, message: "Registration failed", details: format_changeset_errors(changeset)}

      {:error, reason} ->
        Logger.error("User registration failed: #{inspect(reason)}")
        {:error, "Registration failed"}
    end
  end

  @doc """
  Аутентификация пользователя
  """
  def login(_, %{input: %{email: email, password: password}}, _) do
    with {:ok, user} <- Accounts.authenticate_user(email, password),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user) do
      {:ok, %{token: token, user: user}}
    else
      {:error, :invalid_credentials} ->
        {:error, message: "Invalid email or password"}

      {:error, reason} ->
        Logger.error("Login failed: #{inspect(reason)}")
        {:error, "Authentication failed"}
    end
  end

  @doc """
  Получение информации о текущем пользователе
  """
  def get_user(_, %{token: token}, _) when is_binary(token) do
     # Обработка токена с префиксом "Bearer"
     token = case String.split(token, "Bearer ") do
       [token] -> token
       [_, token] -> token
     end

     case Guardian.decode_and_verify(token) do
       {:ok, claims} ->
         case Guardian.resource_from_claims(claims) do
           {:ok, user} -> {:ok, user}
           {:error, reason} ->
             Logger.error("Failed to get user from claims: #{inspect(reason)}")
             {:error, "Invalid token"}
         end
       {:error, reason} ->
         Logger.error("Token verification failed: #{inspect(reason)}")
         {:error, "Invalid token"}
     end
   end

   # Для случая, когда токен передан через контекст
   def get_user(_, _, %{context: %{current_user: current_user}}) do
     {:ok, current_user}
   end

   # Для случая, когда нет ни токена, ни пользователя в контексте
   def get_user(_, _, _) do
     {:error, "Not authenticated"}
   end

  # Вспомогательные функции

  @doc """
  Форматирование ошибок валидации
  """
  defp format_changeset_errors(changeset) do
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
