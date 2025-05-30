"use client";
import { useQuery, gql } from "@apollo/client";
import Link from "next/link";
import { useState } from "react";
import { useAuth } from "../hooks/useAuth";

const GET_BOTS = gql`
  query GetBots($token: String!) {
    bots(token: $token) {
      id
      name
      __typename
    }
  }
`;

export default function NavMenu() {
  const { token } = useAuth();
  const [isBotsOpen, setIsBotsOpen] = useState(false);
  const { data, loading, error } = useQuery(GET_BOTS, {
    variables: { token },
    skip: !token || token === "",
    fetchPolicy: "no-cache", // Для обхода ошибки Invariant Violation
    onError: (err) => {
      console.error(
        "GetBots error:",
        err.message,
        err.graphQLErrors,
        err.networkError,
      );
    },
  });

  const toggleBotsMenu = () => {
    setIsBotsOpen((prev) => !prev);
  };

  return (
    <nav className="nav-menu">
      <ul className="h-12">
        <li>
          <Link href="/" className="nav-item home-icon">
            Главная
          </Link>
        </li>
        <li className="bots-menu">
          <div className="nav-item bots-icon">
            <Link href="/bots" className="bots-link">
              Боты
            </Link>
            <button
              className="nav-toggle"
              onClick={toggleBotsMenu}
              aria-label={
                isBotsOpen ? "Закрыть подменю ботов" : "Открыть подменю ботов"
              }
            ></button>
          </div>
          <div className={`nav-submenu ${isBotsOpen ? "open" : ""}`}>
            {loading && (
              <p className="submenu-item submenu-loading">Загрузка...</p>
            )}
            {error && (
              <p className="submenu-item submenu-error">
                Ошибка загрузки ботов: {error.message}
              </p>
            )}
            {data?.bots && data.bots.length > 0
              ? data.bots.map((bot) => (
                  <Link
                    key={bot.id}
                    href={`/bots/${bot.id}`}
                    className="submenu-item submenu-bot"
                    onClick={() => setIsBotsOpen(false)} // Закрываем подменю при клике
                  >
                    {bot.name}
                  </Link>
                ))
              : !loading &&
                !error && (
                  <p className="submenu-item submenu-empty">Боты отсутствуют</p>
                )}
          </div>
        </li>
      </ul>
    </nav>
  );
}
