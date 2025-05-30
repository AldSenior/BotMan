"use client";
import { useState } from "react";
import { useMutation, gql } from "@apollo/client";
import { useAuth } from "../hooks/useAuth";

const REGISTER_MUTATION = gql`
  mutation Register($input: UserInput!) {
    register(input: $input) {
      token
      user {
        id
        name
        email
        is_admin
      }
    }
  }
`;

const LOGIN_MUTATION = gql`
  mutation Login($input: LoginInput!) {
    login(input: $input) {
      token
      user {
        id
        name
        email
      }
    }
  }
`;

export default function AuthForm() {
  const { login } = useAuth();
  const [activeTab, setActiveTab] = useState("login");
  const [formData, setFormData] = useState({
    email: "",
    name: "",
    password: "",
    retryPassword: "",
  });
  const [error, setError] = useState("");

  const [register, { loading: regLoading }] = useMutation(REGISTER_MUTATION);
  const [loginMutation, { loading: loginLoading }] =
    useMutation(LOGIN_MUTATION);

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    setError("");
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");

    if (
      activeTab === "register" &&
      formData.password !== formData.retryPassword
    ) {
      setError("Пароли не совпадают!");
      return;
    }

    try {
      const variables = {
        input:
          activeTab === "login"
            ? {
                email: formData.email,
                password: formData.password,
              }
            : {
                email: formData.email,
                name: formData.name,
                password: formData.password,
              },
      };

      const { data } =
        activeTab === "login"
          ? await loginMutation({ variables })
          : await register({ variables });

      const token =
        activeTab === "login" ? data.login.token : data.register.token;
      login(token);
    } catch (err) {
      setError(err.message || "Произошла ошибка");
    }
  };

  return (
    <div className="bg-gray-800 flex flex-col w-full max-w-md rounded-2xl overflow-hidden mx-auto my-10 shadow-lg">
      <div className="flex flex-row">
        <button
          className={`w-1/2 py-4 text-center text-base ${activeTab === "login" ? "font-bold bg-gray-700" : "bg-gray-800"}`}
          onClick={() => setActiveTab("login")}
        >
          Вход
        </button>
        <button
          className={`w-1/2 py-4 text-center text-base ${activeTab === "register" ? "font-bold bg-gray-700" : "bg-gray-800"}`}
          onClick={() => setActiveTab("register")}
        >
          Регистрация
        </button>
      </div>
      <form className="flex flex-col gap-4 p-6" onSubmit={handleSubmit}>
        <input
          className="border-0 bg-gray-700 text-white rounded-md px-3 py-2 text-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="Почта"
          type="email"
          name="email"
          value={formData.email}
          onChange={handleInputChange}
          required
        />
        {activeTab === "register" && (
          <input
            className="border-0 bg-gray-700 text-white rounded-md px-3 py-2 text-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Имя"
            type="text"
            name="name"
            value={formData.name}
            onChange={handleInputChange}
            required
          />
        )}
        <input
          className="border-0 bg-gray-700 text-white rounded-md px-3 py-2 text-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="Пароль"
          type="password"
          name="password"
          value={formData.password}
          onChange={handleInputChange}
          required
        />
        {activeTab === "register" && (
          <input
            className="border-0 bg-gray-700 text-white rounded-md px-3 py-2 text-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Повторите пароль"
            type="password"
            name="retryPassword"
            value={formData.retryPassword}
            onChange={handleInputChange}
            required
          />
        )}
        {error && <p className="text-red-500 text-sm text-center">{error}</p>}
        <button
          className="mx-auto mt-2 px-10 bg-blue-600 rounded-lg py-2 hover:bg-blue-700 disabled:opacity-50 transition-colors"
          type="submit"
          disabled={regLoading || loginLoading}
        >
          {activeTab === "login" ? "Вход" : "Регистрация"}
        </button>
      </form>
    </div>
  );
}
