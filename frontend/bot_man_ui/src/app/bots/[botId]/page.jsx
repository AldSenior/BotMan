"use client";
import { useAuth } from "../../hooks/useAuth";
import BotDetails from "../../components/BotDetails";

export default function BotPage() {
  const { token, loading, isClient } = useAuth();

  if (!isClient || loading)
    return <p className="text-center text-lg">Загрузка...</p>;
  if (!token) return null;

  return <BotDetails token={token} />;
}
