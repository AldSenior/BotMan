"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "./hooks/useAuth";

export default function Home() {
  const { user, loading, isClient } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (isClient && !loading) {
      if (user) {
        router.push("/bots");
      } else {
        router.push("/auth");
      }
    }
  }, [user, loading, router, isClient]);

  return null;
}
