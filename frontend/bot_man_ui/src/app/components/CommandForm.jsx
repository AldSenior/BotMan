"use client";
import { useMutation, gql } from "@apollo/client";
import { useState } from "react";
import DropZone from "./DropZone";

const CREATE_COMMAND_MUTATION = gql`
  mutation CreateCommand($input: CommandInput!, $token: String!) {
    createCommand(input: $input, token: $token) {
      id
      name
      trigger
      response_type
      response_content
    }
  }
`;

export default function CommandForm({ botId, token }) {
  const [formData, setFormData] = useState({
    name: "",
    trigger: "",
    response_type: "text",
    response_content: "",
    keyboard_type: "inline",
  });
  const [rows, setRows] = useState([]);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const [createCommand, { loading }] = useMutation(CREATE_COMMAND_MUTATION, {
    onError: (err) => {
      console.error("Create command error:", err);
      let errorMessage = "Ошибка при создании команды";
      if (err.graphQLErrors && err.graphQLErrors.length > 0) {
        const gqlError = err.graphQLErrors[0];
        errorMessage = gqlError.message || "Ошибка валидации";
        if (gqlError.extensions?.details) {
          errorMessage = `Ошибка: ${gqlError.extensions.details}`;
        }
      } else if (err.networkError) {
        errorMessage =
          "Сетевая ошибка: " +
          (err.networkError.message || "Неизвестная ошибка");
      }
      setError(errorMessage);
      setSuccess("");
    },
    onCompleted: () => {
      setError("");
      setSuccess("Команда создана!");
      setFormData({
        name: "",
        trigger: "",
        response_type: "text",
        response_content: "",
        keyboard_type: "inline",
      });
      setRows([]);
      setTimeout(() => setSuccess(""), 3000);
    },
    update: (cache, { data: { createCommand } }) => {
      try {
        cache.modify({
          id: cache.identify({ __typename: "Bot", id: botId }),
          fields: {
            commands(existingCommands = []) {
              const newCommandRef = cache.writeFragment({
                data: createCommand,
                fragment: gql`
                  fragment NewCommand on Command {
                    id
                    name
                    trigger
                    response_type
                    response_content
                  }
                `,
              });
              return [...existingCommands, newCommandRef];
            },
          },
        });
      } catch (err) {
        console.warn("Failed to update cache:", err);
      }
    },
  });

  const validateKeyboard = (rows, keyboard_type) => {
    if (rows.length === 0 || rows.every((row) => row.length === 0)) {
      return "Добавьте хотя бы одну кнопку для клавиатуры!";
    }
    if (keyboard_type === "inline") {
      const allCallbackData = rows.flat().map((btn) => btn.callback_data);
      const uniqueCallbackData = new Set(allCallbackData);
      if (uniqueCallbackData.size !== allCallbackData.length) {
        return "Callback data должны быть уникальными!";
      }
      if (
        rows
          .flat()
          .some(
            (btn) =>
              !btn.text ||
              !btn.callback_data ||
              !btn.action_type ||
              !btn.action_content,
          )
      ) {
        return "Все поля кнопок (текст, callback data, тип действия, содержимое) обязательны!";
      }
    } else {
      if (
        rows
          .flat()
          .some(
            (btn) =>
              (btn.button_type === "text" &&
                (!btn.text ||
                  btn.text.trim() === "" ||
                  !btn.send_text ||
                  btn.send_text.trim() === "" ||
                  !btn.action_type ||
                  !btn.action_content)) ||
              (btn.button_type !== "text" &&
                btn.text &&
                btn.text.trim() === ""),
          )
      ) {
        return "Текстовые кнопки должны содержать непустой текст, send_text, тип действия и содержимое, а для специальных кнопок текст опционален!";
      }
      const allSendText = rows
        .flat()
        .filter((btn) => btn.button_type === "text")
        .map((btn) => btn.send_text);
      const uniqueSendText = new Set(allSendText);
      if (uniqueSendText.size !== allSendText.length) {
        return "Send_text для текстовых кнопок должны быть уникальными!";
      }
      const allButtonText = rows
        .flat()
        .filter((btn) => btn.button_type === "text")
        .map((btn) => btn.text);
      const uniqueButtonText = new Set(allButtonText);
      if (uniqueButtonText.size !== allButtonText.length) {
        return "Текст кнопок (text) для текстовых кнопок должен быть уникальным!";
      }
    }
    return null;
  };

  const handleFileUploaded = (fileData) => {
    if (!fileData) {
      setError("Ошибка: файл не загружен");
      return;
    }
    setFormData((prev) => ({ ...prev, response_content: fileData }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setSuccess("");

    if (!formData.name || !formData.trigger) {
      setError("Заполните название и триггер!");
      return;
    }
    if (!formData.trigger.startsWith("/")) {
      setError("Триггер должен начинаться с '/'");
      return;
    }

    if (
      formData.response_type !== "keyboard" &&
      (!formData.response_content || formData.response_content.trim() === "")
    ) {
      setError("Содержимое ответа не может быть пустым!");
      return;
    }

    if (formData.response_type === "keyboard") {
      const keyboardError = validateKeyboard(rows, formData.keyboard_type);
      if (keyboardError) {
        setError(keyboardError);
        return;
      }

      try {
        const filteredRows = rows.filter((row) => row.length > 0);
        if (filteredRows.length === 0) {
          setError("Добавьте хотя бы одну кнопку!");
          return;
        }

        const allButtons = filteredRows.flat();
        if (formData.keyboard_type === "inline") {
          const keyboardJson = {
            inline_keyboard: filteredRows.map((row) =>
              row.map((btn) => ({
                text: btn.text,
                callback_data: btn.callback_data,
              })),
            ),
            actions: allButtons.reduce(
              (acc, btn) => ({
                ...acc,
                [btn.callback_data]: {
                  type: btn.action_type,
                  content: btn.action_content,
                },
              }),
              {},
            ),
          };
          formData.response_content = JSON.stringify(keyboardJson);
        } else {
          const keyboardJson = {
            keyboard: filteredRows.map((row) =>
              row.map((btn) => {
                if (btn.button_type === "contact") {
                  return {
                    text: btn.text || "Отправить контакт",
                    request_contact: true,
                  };
                } else if (btn.button_type === "location") {
                  return {
                    text: btn.text || "Отправить местоположение",
                    request_location: true,
                  };
                } else {
                  return { text: btn.text, send_text: btn.send_text };
                }
              }),
            ),
            actions: allButtons
              .filter((btn) => btn.button_type === "text")
              .reduce(
                (acc, btn) => ({
                  ...acc,
                  [btn.send_text]: {
                    type: btn.action_type,
                    content: btn.action_content,
                  },
                }),
                {},
              ),
            resize_keyboard: true,
            one_time_keyboard: true,
          };
          formData.response_content = JSON.stringify(keyboardJson);
        }
      } catch (err) {
        setError("Ошибка формирования JSON для клавиатуры: " + err.message);
        return;
      }
    }

    try {
      await createCommand({
        variables: {
          input: {
            bot_id: botId,
            name: formData.name,
            trigger: formData.trigger,
            response_type: formData.response_type.toUpperCase(),
            response_content: formData.response_content,
          },
          token,
        },
      });
    } catch (err) {
      console.error("Submit error:", err);
      setError("Ошибка отправки: " + err.message);
    }
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    if (name === "response_type") {
      setFormData((prev) => ({ ...prev, response_content: "" }));
      setRows([]);
    }
  };

  const addRow = () => {
    if (rows.length >= 5) {
      setError("Максимум 5 рядов!");
      return;
    }
    setRows([...rows, []]);
  };

  const addButtonToRow = (rowIndex) => {
    if (rows[rowIndex].length >= 4) {
      setError("Максимум 4 кнопки в ряду!");
      return;
    }
    const newRows = [...rows];
    const allSendText = rows
      .flat()
      .filter((btn) => btn.button_type === "text")
      .map((btn) => btn.send_text || "");
    let newSendText = `action_${rows.flat().length + 1}`;
    let counter = rows.flat().length + 1;
    while (allSendText.includes(newSendText)) {
      counter++;
      newSendText = `action_${counter}`;
    }
    newRows[rowIndex] = [
      ...newRows[rowIndex],
      formData.keyboard_type === "inline"
        ? {
            text: "",
            callback_data: newSendText,
            action_type: "send_message",
            action_content: "",
          }
        : {
            text: "",
            send_text: newSendText,
            button_type: "text",
            action_type: "send_message",
            action_content: "",
          },
    ];
    setRows(newRows);
  };

  const updateButton = (rowIndex, buttonIndex, field, value) => {
    const newRows = [...rows];
    newRows[rowIndex][buttonIndex] = {
      ...newRows[rowIndex][buttonIndex],
      [field]: value,
    };
    setRows(newRows);
  };

  const removeButton = (rowIndex, buttonIndex) => {
    const newRows = [...rows];
    newRows[rowIndex] = newRows[rowIndex].filter((_, i) => i !== buttonIndex);
    if (newRows[rowIndex].length === 0) {
      newRows.splice(rowIndex, 1);
    }
    setRows(newRows);
  };

  const removeRow = (rowIndex) => {
    setRows(rows.filter((_, i) => i !== rowIndex));
  };

  const fileAccept = {
    sticker: ["image/webp"],
    image: ["image/jpeg", "image/png", "image/gif"],
    video: ["video/mp4", "video/mpeg"],
    animation: ["image/gif", "video/mp4"],
    document: ["application/pdf", "text/plain", "application/msword"],
    voice: ["audio/ogg", "audio/mpeg"],
  };

  return (
    <form
      className="mx-auto p-6 bg-gray-800 text-white shadow-xl rounded-xl"
      onSubmit={handleSubmit}
    >
      <h3 className="text-2xl font-bold mb-6 text-blue-300">
        Добавить команду
      </h3>

      {error && (
        <p className="text-red-500 mb-4 text-sm break-words">{error}</p>
      )}
      {success && (
        <p className="text-green-500 mb-4 text-sm break-words">{success}</p>
      )}

      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-300 mb-1">
          Название
        </label>
        <input
          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white placeholder-gray-400"
          placeholder="Название команды"
          type="text"
          name="name"
          value={formData.name}
          onChange={handleChange}
          required
        />
      </div>

      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-300 mb-1">
          Триггер
        </label>
        <input
          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white placeholder-gray-400"
          placeholder="Триггер (например, /start)"
          type="text"
          name="trigger"
          value={formData.trigger}
          onChange={handleChange}
          required
        />
      </div>

      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-300 mb-1">
          Тип ответа
        </label>
        <select
          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white"
          name="response_type"
          value={formData.response_type}
          onChange={handleChange}
        >
          <option value="text">Текст</option>
          <option value="image">Изображение</option>
          <option value="document">Документ</option>
          <option value="video">Видео</option>
          <option value="sticker">Стикер</option>
          <option value="animation">Анимация</option>
          <option value="voice">Голосовое сообщение</option>
          <option value="keyboard">Клавиатура</option>
        </select>
      </div>

      {formData.response_type === "keyboard" && (
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-300 mb-1">
            Тип клавиатуры
          </label>
          <select
            className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white"
            name="keyboard_type"
            value={formData.keyboard_type}
            onChange={(e) => {
              setFormData((prev) => ({
                ...prev,
                keyboard_type: e.target.value,
              }));
              setRows([]);
            }}
          >
            <option value="inline">Inline Keyboard</option>
            <option value="reply">Reply Keyboard (меню внизу)</option>
          </select>
        </div>
      )}

      {formData.response_type === "keyboard" ? (
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-300 mb-2">
            Кнопки клавиатуры
          </label>
          {rows.map((row, rowIndex) => (
            <div
              key={rowIndex}
              className="mb-4 p-4 border border-gray-700 rounded-md bg-gray-800"
            >
              <div className="flex justify-between items-center mb-2">
                <h4 className="text-sm font-medium text-blue-300">
                  Ряд {rowIndex + 1}
                </h4>
                <button
                  type="button"
                  className="text-red-400 hover:text-red-300 transition-colors"
                  onClick={() => removeRow(rowIndex)}
                >
                  Удалить ряд
                </button>
              </div>
              {row.map((button, buttonIndex) => (
                <div
                  key={buttonIndex}
                  className="mb-2 p-3 border border-gray-600 rounded-md bg-gray-700"
                >
                  <div className="grid grid-cols-1 gap-2">
                    {formData.keyboard_type === "inline" ? (
                      <>
                        <input
                          className="px-3 py-2 bg-gray-800 border border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white placeholder-gray-400"
                          placeholder="Текст кнопки"
                          type="text"
                          value={button.text}
                          onChange={(e) =>
                            updateButton(
                              rowIndex,
                              buttonIndex,
                              "text",
                              e.target.value,
                            )
                          }
                          required
                        />
                        <input
                          className="px-3 py-2 bg-gray-800 border border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white placeholder-gray-400"
                          placeholder="Callback data"
                          type="text"
                          value={button.callback_data}
                          onChange={(e) =>
                            updateButton(
                              rowIndex,
                              buttonIndex,
                              "callback_data",
                              e.target.value,
                            )
                          }
                          required
                        />
                        <select
                          className="px-3 py-2 bg-gray-800 border border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white"
                          value={button.action_type}
                          onChange={(e) =>
                            updateButton(
                              rowIndex,
                              buttonIndex,
                              "action_type",
                              e.target.value,
                            )
                          }
                        >
                          <option value="send_message">
                            Отправить сообщение
                          </option>
                          <option value="send_photo">Отправить фото</option>
                          <option value="send_document">
                            Отправить документ
                          </option>
                          <option value="send_video">Отправить видео</option>
                          <option value="send_sticker">Отправить стикер</option>
                          <option value="send_animation">
                            Отправить анимацию
                          </option>
                          <option value="send_voice">
                            Отправить голосовое сообщение
                          </option>
                        </select>
                        <textarea
                          className="px-3 py-2 bg-gray-800 border border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white placeholder-gray-400"
                          placeholder="Содержимое действия (например, текст, URL или file_id)"
                          value={button.action_content}
                          onChange={(e) =>
                            updateButton(
                              rowIndex,
                              buttonIndex,
                              "action_content",
                              e.target.value,
                            )
                          }
                          rows="2"
                          required
                        />
                      </>
                    ) : (
                      <>
                        <select
                          className="px-3 py-2 bg-gray-800 border border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white"
                          value={button.button_type}
                          onChange={(e) => {
                            updateButton(
                              rowIndex,
                              buttonIndex,
                              "button_type",
                              e.target.value,
                            );
                            if (e.target.value !== "text") {
                              updateButton(rowIndex, buttonIndex, "text", "");
                              updateButton(
                                rowIndex,
                                buttonIndex,
                                "send_text",
                                "",
                              );
                              updateButton(
                                rowIndex,
                                buttonIndex,
                                "action_type",
                                "",
                              );
                              updateButton(
                                rowIndex,
                                buttonIndex,
                                "action_content",
                                "",
                              );
                            }
                          }}
                        >
                          <option value="text">Текстовая кнопка</option>
                          <option value="contact">Запрос контакта</option>
                          <option value="location">
                            Запрос местоположения
                          </option>
                        </select>
                        {button.button_type === "text" ? (
                          <>
                            <input
                              className="px-3 py-2 bg-gray-800 border border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white placeholder-gray-400"
                              placeholder="Текст кнопки (отображение)"
                              type="text"
                              value={button.text}
                              onChange={(e) =>
                                updateButton(
                                  rowIndex,
                                  buttonIndex,
                                  "text",
                                  e.target.value,
                                )
                              }
                              required
                            />
                            <input
                              className="px-3 py-2 bg-gray-800 border border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white placeholder-gray-400"
                              placeholder="Идентификатор действия (send_text)"
                              type="text"
                              value={button.send_text}
                              onChange={(e) =>
                                updateButton(
                                  rowIndex,
                                  buttonIndex,
                                  "send_text",
                                  e.target.value,
                                )
                              }
                              required
                            />
                            <select
                              className="px-3 py-2 bg-gray-800 border border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white"
                              value={button.action_type}
                              onChange={(e) =>
                                updateButton(
                                  rowIndex,
                                  buttonIndex,
                                  "action_type",
                                  e.target.value,
                                )
                              }
                            >
                              <option value="send_message">
                                Отправить сообщение
                              </option>
                              <option value="send_photo">Отправить фото</option>
                              <option value="send_document">
                                Отправить документ
                              </option>
                              <option value="send_video">
                                Отправить видео
                              </option>
                              <option value="send_sticker">
                                Отправить стикер
                              </option>
                              <option value="send_animation">
                                Отправить анимацию
                              </option>
                              <option value="send_voice">
                                Отправить голосовое сообщение
                              </option>
                            </select>
                            <textarea
                              className="px-3 py-2 bg-gray-800 border border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white placeholder-gray-400"
                              placeholder="Содержимое действия (например, текст, URL или file_id)"
                              value={button.action_content}
                              onChange={(e) =>
                                updateButton(
                                  rowIndex,
                                  buttonIndex,
                                  "action_content",
                                  e.target.value,
                                )
                              }
                              rows="2"
                              required
                            />
                          </>
                        ) : (
                          <input
                            className="px-3 py-2 bg-gray-800 border border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white placeholder-gray-400"
                            placeholder="Текст кнопки (опционально)"
                            type="text"
                            value={button.text}
                            onChange={(e) =>
                              updateButton(
                                rowIndex,
                                buttonIndex,
                                "text",
                                e.target.value,
                              )
                            }
                          />
                        )}
                      </>
                    )}
                  </div>
                  <button
                    type="button"
                    className="mt-2 text-red-400 hover:text-red-300 transition-colors"
                    onClick={() => removeButton(rowIndex, buttonIndex)}
                  >
                    Удалить кнопку
                  </button>
                </div>
              ))}
              <button
                type="button"
                className="mt-2 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                onClick={() => addButtonToRow(rowIndex)}
              >
                Добавить кнопку в ряд
              </button>
            </div>
          ))}
          <button
            type="button"
            className="px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition-colors"
            onClick={addRow}
          >
            Добавить ряд
          </button>
        </div>
      ) : fileAccept[formData.response_type] ? (
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-300 mb-1">
            Загрузить файл
          </label>
          <DropZone
            onFileUploaded={handleFileUploaded}
            accept={fileAccept[formData.response_type]}
            responseType={formData.response_type}
            token={token}
          />
          {formData.response_content && (
            <p className="text-gray-400 text-sm mt-2">
              Загружено: {formData.response_content}
            </p>
          )}
        </div>
      ) : (
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-300 mb-1">
            Содержимое ответа
          </label>
          <textarea
            className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white placeholder-gray-400"
            placeholder="Введите содержимое (например, текст или URL)"
            name="response_content"
            value={formData.response_content}
            onChange={handleChange}
            rows="4"
            required
          />
        </div>
      )}

      <button
        type="submit"
        className="w-full px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors disabled:bg-gray-600"
        disabled={loading}
      >
        {loading ? "Создание..." : "Создать команду"}
      </button>
    </form>
  );
}
