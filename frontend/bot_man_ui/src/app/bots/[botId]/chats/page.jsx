"use client";

import { useQuery, gql } from "@apollo/client";
import { useParams, useRouter } from "next/navigation";
import { useState, useEffect } from "react";
import { useAuth } from "../../../hooks/useAuth";

const CHATS_QUERY = gql`
  query GetChats(
    $bot_id: ID!
    $token: String!
    $limit: Int
    $offset: Int
    $search: String
  ) {
    chats(
      bot_id: $bot_id
      token: $token
      limit: $limit
      offset: $offset
      search: $search
    ) {
      id
      chat_id
      title
      type
      inserted_at
      updated_at
    }
  }
`;

const CHAT_MESSAGES_QUERY = gql`
  query GetChatMessages(
    $chat_id: String!
    $bot_id: ID!
    $token: String!
    $limit: Int
    $offset: Int
  ) {
    chat_messages(
      chat_id: $chat_id
      bot_id: $bot_id
      token: $token
      limit: $limit
      offset: $offset
    ) {
      id
      sender_name
      text
      inserted_at
    }
  }
`;

export default function BotChats() {
  const { token, loading: authLoading, isClient } = useAuth();
  const params = useParams();
  const router = useRouter();
  const botId = params?.botId;
  const [errorMessage, setErrorMessage] = useState(null);
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [limit] = useState(20);
  const [chatMessages, setChatMessages] = useState({});

  const { data, loading, error, fetchMore } = useQuery(CHATS_QUERY, {
    variables: {
      bot_id: botId,
      token,
      limit,
      offset: (page - 1) * limit,
      search,
    },
    skip: !botId || !token || !isClient,
    onError: (err) => {
      console.error("CHATS_QUERY error:", {
        message: err.message,
        graphQLErrors: err.graphQLErrors,
        networkError: err.networkError,
        variables: { bot_id: botId, token },
      });
      setErrorMessage(err.message || "Произошла неизвестная ошибка");
    },
  });

  // Запрос последнего сообщения для каждого чата
  const chats = data?.chats || [];
  chats.forEach((chat) => {
    useQuery(CHAT_MESSAGES_QUERY, {
      variables: {
        chat_id: chat.chat_id,
        bot_id: botId,
        token,
        limit: 1,
        offset: 0,
      },
      skip: !chat.chat_id || !botId || !token || !isClient,
      onCompleted: (data) => {
        setChatMessages((prev) => ({
          ...prev,
          [chat.chat_id]: data?.chat_messages || [],
        }));
      },
      onError: (err) => {
        console.error(
          `CHAT_MESSAGES_QUERY error for chat ${chat.chat_id}:`,
          err,
        );
      },
    });
  });

  const handleChatClick = (chatId) => {
    router.push(`/bots/${botId}/chats/${chatId}`);
  };

  const handleSearch = (e) => {
    setSearch(e.target.value);
    setPage(1); // Сбрасываем страницу при новом поиске
  };

  const handleNextPage = () => {
    setPage((prev) => prev + 1);
    fetchMore({
      variables: { offset: page * limit },
      updateQuery: (prev, { fetchMoreResult }) => {
        if (!fetchMoreResult) return prev;
        return {
          chats: [...prev.chats, ...fetchMoreResult.chats],
        };
      },
    });
  };

  const handlePrevPage = () => {
    if (page > 1) setPage((prev) => prev - 1);
  };

  if (!isClient || authLoading) {
    return (
      <p className="text-center text-lg text-gray-300 animate-pulse">
        Загрузка...
      </p>
    );
  }

  if (!botId || !token) {
    console.error("Invalid botId or token:", { botId, token });
    return (
      <p className="text-red-500 text-center text-lg font-semibold">
        Ошибка: Неверный ID бота или токен
      </p>
    );
  }

  if (loading && !data) {
    return (
      <p className="text-center text-lg text-gray-300 animate-pulse">
        Загрузка чатов...
      </p>
    );
  }

  if (error) {
    const errorMsg = error.message.includes("not found")
      ? "Бот не найден"
      : error.message.includes("Invalid token")
        ? "Недействительный токен"
        : error.message.includes("Нет доступа")
          ? "Нет доступа к чатам этого бота"
          : `Произошла ошибка: ${error.message}`;
    return (
      <p className="text-red-500 text-center text-lg font-semibold">
        Ошибка: {errorMsg}
      </p>
    );
  }

  return (
    <div className="flex flex-col min-h-screen bg-gray-900 overflow-auto">
      {/* Header */}
      <div className="bg-gray-900 px-6 py-4">
        <div className="flex justify-between items-center max-w-4xl mx-auto">
          <h1 className="text-2xl md:text-3xl font-bold text-blue-400 break-words max-w-[70%]">
            Чаты бота
          </h1>
          <button
            onClick={() => router.push(`/bots/${botId}`)}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition duration-200 shrink-0"
          >
            Назад к боту
          </button>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="max-w-4xl mx-auto px-6 py-4">
        <input
          type="text"
          value={search}
          onChange={handleSearch}
          placeholder="Поиск по названию чата..."
          className="w-full bg-gray-700 text-white p-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      {/* Main content */}
      <main className="flex-1 px-6 pb-6">
        <div className="max-w-4xl mx-auto space-y-6">
          {errorMessage && (
            <p className="text-red-500 text-sm break-words">{errorMessage}</p>
          )}
          {chats.length === 0 ? (
            <p className="text-gray-400 text-lg">
              Чаты отсутствуют для этого бота.
            </p>
          ) : (
            <div className="grid gap-4">
              {chats.map((chat) => {
                const messages = chatMessages[chat.chat_id] || [];
                return (
                  <div
                    key={chat.id}
                    className="bg-gray-800 p-4 rounded-lg shadow-md flex flex-col sm:flex-row sm:items-center justify-between gap-3 hover:bg-gray-700 transition duration-200 cursor-pointer"
                    onClick={() => handleChatClick(chat.chat_id)}
                  >
                    <div className="flex-1 min-w-0">
                      <p className="text-gray-300 break-words font-medium">
                        {chat.title || `Чат ${chat.chat_id}`}
                      </p>
                      <p className="text-gray-400 text-sm break-words">
                        Тип: {chat.type}
                      </p>
                      <p className="text-gray-500 text-xs mt-1">
                        Создан:{" "}
                        {new Date(chat.inserted_at).toLocaleString("ru-RU")}
                      </p>
                      {messages.length > 0 && (
                        <p className="text-gray-400 text-sm mt-1 truncate">
                          Последнее сообщение: {messages[0].text}
                        </p>
                      )}
                    </div>
                    <div className="text-gray-300 text-sm">
                      Сообщений: {messages.length}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
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
              disabled={chats.length < limit}
              className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition duration-200 disabled:bg-gray-500"
            >
              Следующая
            </button>
          </div>
        </div>
      </main>
    </div>
  );
}
