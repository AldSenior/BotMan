"use client";

import { useQuery, gql } from "@apollo/client";
import { useAuth } from "../hooks/useAuth";
const ME_QUERY = gql`
  query Me($token: String!) {
    me(token: $token) {
      id
      name
      email
      bots {
        id
        name
      }
    }
  }
`;

export default function Dashboard() {
  // Получаем токен контекста аутентификации
  const { token } = useAuth();

  const { data, loading, error } = useQuery(ME_QUERY, {
    variables: { token },
    context: {
      headers: {
        authorization: token ? `Bearer ${token}` : "",
      },
    },
  });

  if (loading) return <p className="text-center mt-4">Загрузка...</p>;
  if (error)
    return (
      <p className="text-center mt-4 text-red-500">Ошибка: {error.message}</p>
    );

  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-4">
        Добро пожаловать, {data?.me?.name}
      </h1>
      <h2 className="text-xl mb-2">Ваши боты:</h2>
      <ul className="list-disc list-inside">
        {data?.me?.bots?.map((bot) => (
          <li key={bot.id}>{bot.name}</li>
        ))}
      </ul>
    </div>
  );
}
