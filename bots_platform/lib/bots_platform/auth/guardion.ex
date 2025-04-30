defmodule BotsPlatform.Auth.Guardian do
  use Guardian, otp_app: :bots_platform

  alias BotsPlatform.Accounts

  def subject_for_token(user, _claims) do
    sub = to_string(user.id)
    {:ok, sub}
  end

  def resource_from_claims(claims) do
    id = claims["sub"]
    user = Accounts.get_user(id)
    {:ok, user}
  end

  @doc """
  Создает токен для пользователя.
  """
  def create_token(user) do
    {:ok, token, _claims} = encode_and_sign(user)
    token
  end

  @doc """
  Проверяет токен и возвращает информацию о пользователе.
  """
  def verify_token(token) do
    case decode_and_verify(token) do
      {:ok, claims} -> resource_from_claims(claims)
      error -> error
    end
  end
end
