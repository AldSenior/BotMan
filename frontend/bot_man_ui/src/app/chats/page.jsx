"use client";

import { useQuery, gql } from "@apollo/client";
import { useParams, useRouter } from "next/navigation";
import { useState } from "react";

const CHATS_QUERY = gql`
  query GetChats($bot_id: ID!, $token: String!) {
    chats(bot_id: $bot_id, token: $token) {
      id
      chat_id
      title
      type
      inserted_at
      updated_at
      messages {
        id
        sender_name
        text
        inserted_at
      }
    }
  }
`;

export default function BotChats({ token }) {
  const params = useParams();
  const router = useRouter();
  const botId = params?.idd;
  const [errorMessage, setErrorMessage] = useState(null);

  if (!botId || !token) {
    console.error("Invalid botId or token:", { botId, token });
    return (
      <p className="text-red-500 text-center text-lg font-semibold">
        Ошибка: Неверный ID бота или токен
      </p>
    );
  }

  const { data, loading, error } = useQuery(CHATS_QUERY, {
    variables: { bot_id: botId, token },
    skip: !botId || !token,
    onError: (err) => {
      console.error("CHATS_QUERY error:", err);
      setErrorMessage(err.message);
    },
  });

  const handleChatClick = (chatId) => {
    // Navigate to a chat details page or handle chat interaction
    router.push(`/bots/${botId}/chats/${chatId}`);
  };

  if (loading) {
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

  const chats = data?.chats || [];

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
              {chats.map((chat) => (
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
                    {chat.messages.length > 0 && (
                      <p className="text-gray-400 text-sm mt-1 truncate">
                        Последнее сообщение: {chat.messages[0].text}
                      </p>
                    )}
                  </div>
                  <div className="text-gray-300 text-sm">
                    Сообщений: {chat.messages.length}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
