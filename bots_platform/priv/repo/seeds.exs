# Скрипт для заполнения базы данных тестовыми данными
alias BotsPlatform.Repo
alias BotsPlatform.Accounts
alias BotsPlatform.Bots
alias BotsPlatform.Subscriptions

# Создаем администратора
{:ok, admin} =
  Accounts.create_user(%{
    name: "Admin",
    email: "admin@example.com",
    password: "password",
    is_admin: true
  })

# Создаем обычного пользователя
{:ok, user} =
  Accounts.create_user(%{
    name: "User",
    email: "user@example.com",
    password: "password"
  })

# Создаем бота для админа
{:ok, admin_bot} =
  Bots.create_bot(%{
    name: "Admin Bot",
    # В реальности используйте настоящий токен
    token: "admin_bot_token",
    description: "Тестовый бот администратора",
    user_id: admin.id,
    is_active: true
  })

# Создаем бота для пользователя
{:ok, user_bot} =
  Bots.create_bot(%{
    name: "User Bot",
    # В реальности используйте настоящий токен
    token: "user_bot_token",
    description: "Тестовый бот пользователя",
    user_id: user.id,
    is_active: true
  })

# Создаем команды для ботов
{:ok, _command1} =
  Bots.create_command(%{
    name: "Help Command",
    description: "Displays help message",
    trigger: "/help",
    response_type: "text",
    response_content: "This is a help message for the bot",
    bot_id: admin_bot.id
  })

{:ok, _command2} =
  Bots.create_command(%{
    name: "Start Command",
    description: "Displays welcome message",
    trigger: "/start",
    response_type: "text",
    response_content: "Welcome to the bot!",
    bot_id: user_bot.id
  })

# Создаем перекрестные подписки
{:ok, _subscription1} = Subscriptions.create_subscription(admin.id, user_bot.id)
{:ok, _subscription2} = Subscriptions.create_subscription(user.id, admin_bot.id)

IO.puts("Seed data created successfully!")
