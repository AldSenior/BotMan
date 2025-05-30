"use client";

import { useQuery, useMutation, gql } from "@apollo/client";
import { useParams, useRouter } from "next/navigation";
import { useState } from "react";
import CommandForm from "./CommandForm";

const BOT_QUERY = gql`
  query GetBot($id: ID!, $token: String!) {
    bot(id: $id, token: $token) {
      id
      name
      description
      isActive
      webhookUrl
      token
      commands {
        id
        name
        trigger
        response_type
        response_content
      }
    }
  }
`;

const UPDATE_BOT_MUTATION = gql`
  mutation UpdateBot($id: ID!, $input: BotInput!, $token: String!) {
    updateBot(id: $id, input: $input, token: $token) {
      id
      name
      description
      isActive
      webhookUrl
      token
    }
  }
`;

const DELETE_COMMAND_MUTATION = gql`
  mutation DeleteCommand($id: ID!, $token: String!) {
    deleteCommand(id: $id, token: $token) {
      id
      name
      trigger
      response_type
      response_content
    }
  }
`;

const DELETE_BOT_MUTATION = gql`
  mutation DeleteBot($id: ID!, $token: String!) {
    deleteBot(id: $id, token: $token) {
      id
      success
      message
    }
  }
`;

export default function BotDetails({ token }) {
  const params = useParams();
  const router = useRouter();
  const id = params?.botId;
  const [errorMessage, setErrorMessage] = useState(null);
  const [successMessage, setSuccessMessage] = useState(null);
  const [isToggling, setIsToggling] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [showDeleteCommandModal, setShowDeleteCommandModal] = useState(null);
  const [showToggleStatusModal, setShowToggleStatusModal] = useState(false);
  const [targetStatus, setTargetStatus] = useState(null);

  console.log("BotDetails params:", params);
  console.log("BotDetails token:", token);

  if (!id || !token) {
    console.error("Invalid id or token:", { id, token });
    return (
      <p className="text-red-500 text-center text-lg font-semibold">
        Ошибка: Неверный ID бота или токен
      </p>
    );
  }

  const { data, loading, error } = useQuery(BOT_QUERY, {
    variables: { id, token },
    skip: !id || !token,
    onError: (err) => {
      console.error("BOT_QUERY error:", err);
      console.error("Error details:", err.graphQLErrors, err.networkError);
    },
  });

  const [updateBot] = useMutation(UPDATE_BOT_MUTATION, {
    onError: (err) => {
      console.error("Update bot error:", err);
      setErrorMessage(err.message);
      setIsToggling(false);
      setShowToggleStatusModal(false);
    },
    onCompleted: () => {
      setErrorMessage(null);
      setSuccessMessage("Статус бота обновлён!");
      setIsToggling(false);
      setShowToggleStatusModal(false);
      setTimeout(() => setSuccessMessage(null), 3000);
    },
  });

  const [deleteCommand] = useMutation(DELETE_COMMAND_MUTATION, {
    onError: (err) => {
      console.error("Delete command error:", err);
      setErrorMessage(err.message);
    },
    onCompleted: () => {
      setErrorMessage(null);
      setSuccessMessage("Команда удалена!");
      setShowDeleteCommandModal(null);
      setTimeout(() => setSuccessMessage(null), 3000);
    },
  });

  const [deleteBot] = useMutation(DELETE_BOT_MUTATION, {
    onCompleted: (data) => {
      if (data.deleteBot.success) {
        setErrorMessage(null);
        setSuccessMessage(data.deleteBot.message || "Бот удалён!");
        setShowDeleteModal(false);
        setTimeout(() => {
          router.push("/");
        }, 2000);
      } else {
        setErrorMessage(data.deleteBot.message || "Не удалось удалить бота");
        setShowDeleteModal(false);
      }
    },
    onError: (err) => {
      console.error("Ошибка удаления бота:", err);
      let errorMessage = "Не удалось удалить бота";
      if (err.graphQLErrors && err.graphQLErrors.length > 0) {
        errorMessage = err.graphQLErrors[0].message;
      } else if (err.networkError) {
        errorMessage =
          "Сетевая ошибка: " +
          (err.networkError.message || "Неизвестная сетевая ошибка");
      }
      setErrorMessage(errorMessage);
      setShowDeleteModal(false);
    },
  });

  const handleToggleActive = async (newStatus) => {
    if (!data?.bot) {
      setErrorMessage("Данные бота недоступны");
      setIsToggling(false);
      setShowToggleStatusModal(false);
      return;
    }
    if (!data.bot.name || !data.bot.token) {
      setErrorMessage("Обязательные поля name или token отсутствуют");
      setIsToggling(false);
      setShowToggleStatusModal(false);
      return;
    }

    setIsToggling(true);
    try {
      const variables = {
        id,
        input: {
          name: data.bot.name,
          description: data.bot.description,
          isActive: newStatus,
          webhookUrl: data.bot.webhookUrl,
          token: data.bot.token,
        },
        token,
      };
      console.log("Sending updateBot with variables:", variables);
      await updateBot({
        variables,
        optimisticResponse: {
          updateBot: {
            __typename: "Bot",
            id,
            name: data.bot.name,
            description: data.bot.description,
            isActive: newStatus,
            webhookUrl: data.bot.webhookUrl,
            token: data.bot.token,
          },
        },
      });
    } catch (err) {
      console.error("Toggle active error:", err);
      setIsToggling(false);
      setShowToggleStatusModal(false);
    }
  };

  const handleOpenToggleModal = (currentStatus) => {
    setTargetStatus(!currentStatus);
    setShowToggleStatusModal(true);
  };

  const handleDeleteCommand = async (commandId) => {
    try {
      await deleteCommand({
        variables: { id: commandId, token },
        update: (cache) => {
          const existing = cache.readQuery({
            query: BOT_QUERY,
            variables: { id, token },
          });
          if (existing) {
            cache.writeQuery({
              query: BOT_QUERY,
              variables: { id, token },
              data: {
                bot: {
                  ...existing.bot,
                  commands: existing.bot.commands.filter(
                    (cmd) => cmd.id !== commandId,
                  ),
                },
              },
            });
          } else {
            console.warn("Cache is empty for BOT_QUERY");
          }
        },
      });
    } catch (err) {
      console.error("Delete command error:", err);
      setErrorMessage(err.message);
    }
  };

  const handleDeleteBot = () => {
    deleteBot({
      variables: { id, token },
    });
  };

  const handleViewChats = () => {
    router.push(`/bots/${id}/chats`);
  };

  if (loading)
    return (
      <p className="text-center text-lg text-gray-300 animate-pulse">
        Загрузка...
      </p>
    );
  if (error) {
    console.error("GraphQL error:", error);
    const errorMsg = error.message.includes("not found")
      ? "Бот не найден"
      : error.message.includes("Invalid token")
        ? "Недействительный токен"
        : `Произошла ошибка при загрузке бота: ${error.message}`;
    return (
      <p className="text-red-500 text-center text-lg font-semibold">
        Ошибка: {errorMsg}
      </p>
    );
  }

  const bot = data?.bot;

  return (
    <div className="flex flex-col min-h-screen bg-gray-900 overflow-auto">
      {/* Header */}
      <div className="bg-gray-900 px-6 py-4">
        <div className="flex justify-between items-center max-w-4xl mx-auto">
          <h1 className="text-2xl md:text-3xl font-bold text-blue-400 break-words max-w-[50%]">
            {bot.name}
          </h1>
          <div className="flex gap-2">
            <button
              onClick={handleViewChats}
              className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition duration-200 shrink-0"
            >
              Чаты бота
            </button>
            <button
              onClick={() => setShowDeleteModal(true)}
              className="bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition duration-200 shrink-0"
            >
              Удалить бота
            </button>
          </div>
        </div>
      </div>

      {/* Main content */}
      <main className="flex-1 px-6 pb-6">
        <div className="max-w-4xl mx-auto space-y-6">
          {/* Bot Info */}
          <div className="bg-gray-800 p-6 rounded-lg shadow-lg">
            <p className="text-gray-300 mb-4 break-words">
              {bot.description || "Без описания"}
            </p>

            <div className="flex flex-wrap items-center gap-4 mb-4">
              <div className="flex items-center">
                <label className="text-sm text-gray-400 mr-2">Статус:</label>
                <input
                  type="checkbox"
                  checked={bot.isActive}
                  onChange={() => handleOpenToggleModal(bot.isActive)}
                  className="form-checkbox h-5 w-5 text-blue-600"
                  disabled={isToggling}
                />
                <span className="ml-2 text-sm text-gray-300">
                  {isToggling
                    ? "Обновление..."
                    : bot.isActive
                      ? "Активен"
                      : "Неактивен"}
                </span>
              </div>

              {errorMessage && (
                <p className="text-red-500 text-sm break-words">
                  {errorMessage}
                </p>
              )}
              {successMessage && (
                <p className="text-green-500 text-sm break-words">
                  {successMessage}
                </p>
              )}
            </div>

            <div className="space-y-2 break-words">
              <p className="text-sm text-gray-400">
                <span className="font-medium">Webhook:</span>{" "}
                {bot.webhookUrl || "Не указан"}
              </p>
              <p className="text-sm text-gray-400">
                <span className="font-medium">Token:</span>{" "}
                {bot.token || "Не указан"}
              </p>
            </div>
          </div>

          {/* Command Form */}
          <CommandForm botId={id} token={token} />

          {/* Commands List */}
          <div>
            <h2 className="text-xl md:text-2xl font-bold text-blue-400 mb-4">
              Команды
            </h2>

            {bot.commands.length === 0 ? (
              <p className="text-gray-400">
                Команды отсутствуют. Добавьте новую команду выше.
              </p>
            ) : (
              <div className="grid gap-4">
                {bot.commands.map((command) => (
                  <div
                    key={command.id}
                    className="bg-gray-800 p-4 rounded-lg shadow-md flex flex-col sm:flex-row sm:items-center justify-between gap-3 hover:bg-gray-700 transition duration-200"
                  >
                    <div className="flex-1 min-w-0">
                      <p className="text-gray-300 break-words">
                        <strong>{command.name}</strong> ({command.trigger})
                      </p>
                      <p className="text-gray-400 text-sm break-words">
                        {command.response_content}
                      </p>
                      <p className="text-gray-500 text-xs mt-1">
                        Тип: {command.response_type}
                      </p>
                    </div>
                    <button
                      onClick={() => setShowDeleteCommandModal(command.id)}
                      className="bg-red-600 text-white px-3 py-1 rounded-lg hover:bg-red-700 transition duration-200 self-end sm:self-center"
                    >
                      Удалить
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </main>

      {/* Toggle Status Modal */}
      {showToggleStatusModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-gray-800 p-6 rounded-lg shadow-lg max-w-sm w-full">
            <h2 className="text-xl font-bold text-blue-400 mb-4">
              {targetStatus ? "Активировать бота" : "Деактивировать бота"}
            </h2>
            <p className="text-gray-300 mb-6">
              Вы уверены, что хотите{" "}
              {targetStatus ? "активировать" : "деактивировать"} бота "
              {bot.name}"?
            </p>
            <div className="flex justify-end gap-4">
              <button
                onClick={() => setShowToggleStatusModal(false)}
                className="bg-gray-600 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition duration-200"
              >
                Отмена
              </button>
              <button
                onClick={() => handleToggleActive(targetStatus)}
                className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition duration-200"
              >
                {targetStatus ? "Активировать" : "Деактивировать"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Bot Modal */}
      {showDeleteModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-gray-800 p-6 rounded-lg shadow-lg max-w-sm w-full">
            <h2 className="text-xl font-bold text-blue-400 mb-4">
              Удалить бота
            </h2>
            <p className="text-gray-300 mb-6">
              Вы уверены, что хотите удалить бота "{bot.name}"? Это действие
              нельзя отменить.
            </p>
            <div className="flex justify-end gap-4">
              <button
                onClick={() => setShowDeleteModal(false)}
                className="bg-gray-600 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition duration-200"
              >
                Отмена
              </button>
              <button
                onClick={handleDeleteBot}
                className="bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition duration-200"
              >
                Удалить
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Command Modal */}
      {showDeleteCommandModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-gray-800 p-6 rounded-lg shadow-lg max-w-sm w-full">
            <h2 className="text-xl font-bold text-blue-400 mb-4">
              Удалить команду
            </h2>
            <p className="text-gray-300 mb-6">
              Вы уверены, что хотите удалить эту команду? Это действие нельзя
              отменить.
            </p>
            <div className="flex justify-end gap-4">
              <button
                onClick={() => setShowDeleteCommandModal(null)}
                className="bg-gray-600 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition duration-200"
              >
                Отмена
              </button>
              <button
                onClick={() => handleDeleteCommand(showDeleteCommandModal)}
                className="bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition duration-200"
              >
                Удалить
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
