defmodule BotsPlatform.Accounts do
  import Ecto.Query
  alias BotsPlatform.Repo
  alias BotsPlatform.Accounts.User

  def data() do
    Dataloader.Ecto.new(Repo, query: &query/2)
  end

  def query(queryable, _params) do
    queryable
  end

  @doc """
  Создает нового пользователя.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Получает пользователя по ID.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Получает пользователя по email.
  """
  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  @doc """
  Аутентифицирует пользователя.
  """
  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    with %User{} <- user,
         true <- Bcrypt.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      nil -> Bcrypt.no_user_verify() && {:error, :invalid_credentials}
      false -> {:error, :invalid_credentials}
    end
  end

  @doc """
  Список всех пользователей.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Обновляет пользователя.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Удаляет пользователя.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Получает список подписанных ботов пользователя.
  """
  def get_user_subscribed_bots(user_id) do
    User
    |> Repo.get(user_id)
    |> Repo.preload(:subscribed_bots)
    |> Map.get(:subscribed_bots)
  end
end
