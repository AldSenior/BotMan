"use client";
import { useState } from "react";
import { useAuth } from "../hooks/useAuth";
import BotList from "../components/BotList";
import BotCreateForm from "../components/BotCreateForm";

export default function BotsPage() {
  const { user, token, loading, isClient } = useAuth();
  const [refetchTrigger, setRefetchTrigger] = useState(0);

  if (!isClient || loading)
    return <p className="text-center text-lg">Загрузка...</p>;
  if (!user) return null;

  return (
    <div className="max-w-4xl w-full mx-auto p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">Мои боты</h1>
        <button
          onClick={() => {
            localStorage.removeItem("authToken");
            window.location.href = "/auth";
          }}
          className="px-4 py-2 bg-red-600 rounded-lg hover:bg-red-700"
        >
          Выйти
        </button>
      </div>
      <BotCreateForm
        token={token}
        onSuccess={() => setRefetchTrigger((prev) => prev + 1)}
      />
      <div className="mt-8">
        <BotList token={token} key={refetchTrigger} />
      </div>
    </div>
  );
}
