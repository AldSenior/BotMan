"use client";
import { useQuery, gql } from "@apollo/client";
import Link from "next/link";

const BOTS_QUERY = gql`
  query GetBots($token: String!) {
    bots(token: $token) {
      id
      name
      description
      is_active
      webhook_url
      user {
        id
        name
      }
      commands {
        id
        name
      }
    }
  }
`;

export default function BotList({ token }) {
  const { data, loading, error } = useQuery(BOTS_QUERY, {
    variables: { token },
  });

  if (loading) return <p className="text-center text-lg">Загрузка...</p>;
  if (error)
    return <p className="text-red-500 text-center">Ошибка: {error.message}</p>;

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
      {data.bots.map((bot) => (
        <div
          key={bot.id}
          className="bg-gray-800 p-4 rounded-lg shadow-md hover:shadow-lg transition-shadow"
        >
          <h3 className="text-lg font-bold text-blue-400">{bot.name}</h3>
          <p className="text-gray-400 text-sm">
            {bot.description || "Без описания"}
          </p>
          <p className="text-sm mt-2">
            Статус: {bot.is_active ? "Активен" : "Неактивен"}
          </p>
          <p className="text-sm">Команд: {bot.commands.length}</p>
          <Link href={`/bots/${bot.id}`}>
            <span className="text-blue-500 hover:underline mt-2 inline-block">
              Подробности
            </span>
          </Link>
        </div>
      ))}
    </div>
  );
}
