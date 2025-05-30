"use client";

import { useQuery, useMutation, useSubscription, gql } from "@apollo/client";
import { useParams, useRouter } from "next/navigation";
import { useState, useEffect, useRef } from "react";
import { useAuth } from "../../../../hooks/useAuth";

const CHAT_QUERY = gql`
  query GetChat(
    $chat_id: String!
    $bot_id: ID!
    $token: String!
    $limit: Int
    $offset: Int
    $search: String
  ) {
    chat(chat_id: $chat_id, bot_id: $bot_id, token: $token) {
      id
      chat_id
      title
      type
      inserted_at
      updated_at
      messages(limit: $limit, offset: $offset, search: $search) {
        id
        sender_id
        sender_name
        text
        inserted_at
      }
    }
  }
`;

const CREATE_MESSAGE_MUTATION = gql`
  mutation CreateMessage($input: MessageInput!, $token: String!) {
    create_message(input: $input, token: $token) {
      id
      chat_id
      sender_id
      sender_name
      text
      inserted_at
    }
  }
`;

const NEW_MESSAGE_SUBSCRIPTION = gql`
  subscription NewMessage($bot_id: ID!, $token: String!) {
    new_message(bot_id: $bot_id, token: $token) {
      id
      chat_id
      sender_id
      sender_name
      text
      inserted_at
    }
  }
`;

export default function ChatDetails() {
  const { token, loading: authLoading, isClient } = useAuth();
  const params = useParams();
  const router = useRouter();
  const botId = params?.botId;
  const chatId = params?.chatId;
  const [messageText, setMessageText] = useState("");
  const [errorMessage, setErrorMessage] = useState(null);
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [limit] = useState(50);
  const messagesEndRef = useRef(null);

  const isValidUUID = (str) =>
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str);

  // Запрос данных чата
  const { data, loading, error, fetchMore } = useQuery(CHAT_QUERY, {
    variables: {
      chat_id: chatId,
      bot_id: botId,
      token,
      limit,
      offset: (page - 1) * limit,
      search,
    },
    skip: !token || !botId || !chatId || !isValidUUID(botId) || !isClient,
    onError: (err) => {
      console.error("CHAT_QUERY error:", {
        message: err.message,
        graphQLErrors: err.graphQLErrors,
        networkError: err.networkError,
        variables: { chat_id: chatId, bot_id: botId, token },
      });
      setErrorMessage(err.message || "Произошла неизвестная ошибка");
    },
  });

  // Мутация для отправки сообщения
  const [createMessage, { loading: mutationLoading }] = useMutation(
    CREATE_MESSAGE_MUTATION,
    {
      onError: (err) => {
        console.error("CREATE_MESSAGE error:", err);
        setErrorMessage(`Ошибка отправки сообщения: ${err.message}`);
      },
      onCompleted: () => {
        setMessageText("");
        scrollToBottom();
      },
    },
  );

  // Подписка на новые сообщения
  const { data: subscriptionData } = useSubscription(NEW_MESSAGE_SUBSCRIPTION, {
    variables: { bot_id: botId, token },
    skip: !token || !botId || !isValidUUID(botId) || !isClient,
    onError: (err) => {
      console.error("NEW_MESSAGE_SUBSCRIPTION error:", err);
      setErrorMessage(`Ошибка подписки: ${err.message}`);
    },
  });

  // Список сообщений
  const [messages, setMessages] = useState([]);
  useEffect(() => {
    if (data?.chat?.messages) {
      setMessages(data.chat.messages);
    }
  }, [data]);

  useEffect(() => {
    if (subscriptionData?.new_message?.chat_id === chatId) {
      setMessages((prev) => {
        if (prev.some((msg) => msg.id === subscriptionData.new_message.id)) {
          return prev;
        }
        return [...prev, subscriptionData.new_message];
      });
      scrollToBottom();
    }
  }, [subscriptionData, chatId]);

  // Прокрутка к последнему сообщению
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  // Пагинация
  const handleNextPage = () => {
    setPage((prev) => prev + 1);
    fetchMore({
      variables: { offset: page * limit },
      updateQuery: (prev, { fetchMoreResult }) => {
        if (!fetchMoreResult) return prev;
        return {
          chat: {
            ...prev.chat,
            messages: [...prev.chat.messages, ...fetchMoreResult.chat.messages],
          },
        };
      },
    });
  };

  const handlePrevPage = () => {
    if (page > 1) setPage((prev) => prev - 1);
  };

  // Обработчик отправки сообщения
  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!messageText.trim()) {
      setErrorMessage("Сообщение не может быть пустым");
      return;
    }

    try {
      await createMessage({
        variables: {
          input: {
            chat_id: chatId,
            text: messageText,
            bot_id: botId,
          },
          token,
        },
      });
    } catch (err) {
      console.error("Failed to send message:", err);
    }
  };

  // Обработчик поиска
  const handleSearch = (e) => {
    setSearch(e.target.value);
    setPage(1);
  };

  // Обработчик возврата
  const handleBack = () => {
    router.push(`/bots/${botId}/chats`);
  };

  if (!isClient || authLoading) {
    return (
      <p className="text-center text-lg text-gray-300 animate-pulse">
        Загрузка...
      </p>
    );
  }

  if (!token || !botId || !chatId || !isValidUUID(botId)) {
    console.error("Invalid token, botId, or chatId:", { token, botId, chatId });
    return (
      <p className="text-red-500 text-center text-lg font-semibold">
        Ошибка: Неверный токен, ID бота или ID чата
      </p>
    );
  }

  if (loading && !data) {
    return (
      <p className="text-center text-lg text-gray-300 animate-pulse">
        Загрузка чата...
      </p>
    );
  }

  if (error) {
    const errorMsg = error.message.includes("not found")
      ? "Чат или бот не найден"
      : error.message.includes("Invalid token")
        ? "Недействительный токен"
        : error.message.includes("Нет доступа")
          ? "Нет доступа к этому чату"
          : `Произошла ошибка: ${error.message}`;
    return (
      <p className="text-red-500 text-center text-lg font-semibold">
        Ошибка: {errorMsg}
      </p>
    );
  }

  const chat = data?.chat || {};
  const chatTitle = chat.title || `Чат ${chat.chat_id}`;

  return (
    <div className="flex flex-col min-h-screen bg-gray-900">
      {/* Header */}
      <div className="bg-gray-900 px-6 py-4 border-b border-gray-700">
        <div className="flex justify-between items-center max-w-4xl mx-auto">
          <h1 className="text-2xl md:text-3xl font-bold text-blue-400 break-words max-w-[70%]">
            {chatTitle}
          </h1>
          <button
            onClick={handleBack}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition duration-200 shrink-0"
          >
            Назад к чатам
          </button>
        </div>
      </div>

      {/* Search */}
      <div className="max-w-4xl mx-auto px-6 py-4">
        <input
          type="text"
          value={search}
          onChange={handleSearch}
          placeholder="Поиск по сообщениям..."
          className="w-full bg-gray-700 text-white p-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      {/* Main content */}
      <main className="flex-1 px-6 pb-6 flex flex-col">
        <div className="max-w-4xl mx-auto flex-1 flex flex-col">
          {/* Messages */}
          <div className="flex-1 overflow-y-auto space-y-4 py-4">
            {messages.length === 0 ? (
              <p className="text-gray-400 text-center">Сообщения отсутствуют</p>
            ) : (
              messages.map((message) => (
                <div
                  key={message.id}
                  className={`flex ${
                    message.sender_id === chat.bot?.telegram_user_id
                      ? "justify-end"
                      : "justify-start"
                  }`}
                >
                  <div
                    className={`max-w-[70%] p-3 rounded-lg ${
                      message.sender_id === chat.bot?.telegram_user_id
                        ? "bg-blue-600 text-white"
                        : "bg-gray-700 text-gray-200"
                    }`}
                  >
                    <p className="text-sm font-semibold">
                      {message.sender_name}
                    </p>
                    <p className="break-words">{message.text}</p>
                    <p className="text-xs text-gray-400 mt-1">
                      {new Date(message.inserted_at).toLocaleString("ru-RU")}
                    </p>
                  </div>
                </div>
              ))
            )}
            <div ref={messagesEndRef} />
          </div>

          {/* Pagination */}
          <div className="flex justify-between mt-4">
            <button
              onClick={handlePrevPage}
              disabled={page === 1}
              className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition duration-200 disabled:bg-gray-500"
            >
              Предыдущая
            </button>
            <span className="text-gray-300">Страница {page}</span>
            <button
              onClick={handleNextPage}
              disabled={messages.length < limit}
              className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition duration-200 disabled:bg-gray-500"
            >
              Следующая
            </button>
          </div>

          {/* Message input */}
          {errorMessage && (
            <p className="text-red-500 text-sm text-center mb-4">
              {errorMessage}
            </p>
          )}
          <form
            onSubmit={handleSendMessage}
            className="flex items-center gap-2 bg-gray-800 p-4 rounded-lg"
          >
            <input
              type="text"
              value={messageText}
              onChange={(e) => setMessageText(e.target.value)}
              placeholder="Введите сообщение..."
              className="flex-1 bg-gray-700 text-white p-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              disabled={mutationLoading}
            />
            <button
              type="submit"
              className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition duration-200 disabled:bg-gray-500"
              disabled={mutationLoading}
            >
              {mutationLoading ? "Отправка..." : "Отправить"}
            </button>
          </form>
        </div>
      </main>
    </div>
  );
}
