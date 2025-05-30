"use client";
import { useMutation, gql } from "@apollo/client";
import { useState } from "react";
import { useRouter } from "next/navigation";

const CREATE_BOT_MUTATION = gql`
  mutation CreateBot($input: BotInput!, $token: String!) {
    createBot(input: $input, token: $token) {
      id
      name
      description
      isActive
      webhookUrl
      token
    }
  }
`;

export default function BotCreateForm({ token }) {
  const router = useRouter();
  const [formData, setFormData] = useState({
    name: "",
    description: "",
    isActive: false,
    webhookUrl: "",
    token: "",
  });
  const [error, setError] = useState("");

  const [createBot, { loading }] = useMutation(CREATE_BOT_MUTATION, {
    onError: (err) => {
      console.error("Create bot error:", err);
      let errorMessage = "Произошла ошибка при создании бота";
      if (err.graphQLErrors && err.graphQLErrors.length > 0) {
        errorMessage = err.graphQLErrors[0].message;
      } else if (err.networkError) {
        errorMessage =
          "Сетевая ошибка: " +
          (err.networkError.message || "Неизвестная сетевая ошибка");
      }
      setError(errorMessage);
    },
    onCompleted: () => {
      setError("");
      router.push("/bots");
    },
  });

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");

    if (!formData.name || !formData.token) {
      setError("Поля Имя бота и Токен бота обязательны");
      return;
    }

    try {
      await createBot({
        variables: {
          input: {
            name: formData.name,
            description: formData.description,
            isActive: formData.isActive,
            webhookUrl: formData.webhookUrl,
            token: formData.token,
          },
          token,
        },
      });
    } catch (err) {
      console.error("Submit error:", err);
      setError(err.message || "Произошла ошибка");
    }
  };

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: type === "checkbox" ? checked : value,
    }));
    setError("");
  };

  return (
    <form className="form card" onSubmit={handleSubmit}>
      <h2>Создать нового бота</h2>
      <div>
        <label>Имя бота</label>
        <input
          placeholder="Имя бота"
          type="text"
          name="name"
          value={formData.name}
          onChange={handleChange}
          required
        />
      </div>
      <div>
        <label>Описание</label>
        <textarea
          placeholder="Описание"
          name="description"
          value={formData.description}
          onChange={handleChange}
        />
      </div>
      <div>
        <label>Токен бота</label>
        <input
          placeholder="Токен бота"
          type="text"
          name="token"
          value={formData.token}
          onChange={handleChange}
          required
        />
      </div>
      <div>
        <label>Webhook URL (необязательно)</label>
        <input
          placeholder="Webhook URL (необязательное)"
          type="url"
          name="webhookUrl"
          value={formData.webhookUrl}
          onChange={handleChange}
        />
      </div>
      <div className="checkbox-container">
        <input
          type="checkbox"
          name="isActive"
          checked={formData.isActive}
          onChange={handleChange}
        />
        <span>Активен</span>
      </div>
      {error && <p className="error-message">{error}</p>}
      <button
        className="button button-primary"
        type="submit"
        disabled={loading}
      >
        Создать
      </button>
    </form>
  );
}
