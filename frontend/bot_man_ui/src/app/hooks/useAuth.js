"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useQuery, gql } from "@apollo/client";

const ME_QUERY = gql`
  query Me($token: String!) {
    me(token: $token) {
      id
      name
      email
      is_admin
      bots {
        id
        name
        __typename
      }
      __typename
    }
  }
`;

export const useAuth = () => {
  const router = useRouter();
  const [token, setToken] = useState(null);
  const [user, setUser] = useState(null);
  const [isClient, setIsClient] = useState(false);

  useEffect(() => {
    setIsClient(true);
    const storedToken =
      typeof window !== "undefined" ? localStorage.getItem("authToken") : null;
    console.log("Stored token:", storedToken);
    if (storedToken) {
      setToken(storedToken);
    }
  }, []);

  const { data, loading, error } = useQuery(ME_QUERY, {
    variables: { token },
    skip: !token || !isClient,
    fetchPolicy: "no-cache", // Отключаем кэш для обхода ошибки
    onError: (err) => {
      console.error(
        "ME_QUERY error:",
        err.message,
        err.graphQLErrors,
        err.networkError,
      );
    },
  });

  useEffect(() => {
    if (data?.me) {
      console.log("User data:", data.me);
      setUser(data.me);
    }
    if (error && isClient) {
      console.warn("Auth error, redirecting to /auth:", error.message);
      localStorage.removeItem("authToken");
      setToken(null);
      setUser(null);
      router.push("/auth");
    }
  }, [data, error, router, isClient]);

  const login = (newToken) => {
    console.log("Logging in with token:", newToken);
    localStorage.setItem("authToken", newToken);
    setToken(newToken);
    router.push("/bots");
  };

  const logout = () => {
    console.log("Logging out");
    localStorage.removeItem("authToken");
    setToken(null);
    setUser(null);
    router.push("/auth");
  };

  return { user, token, loading, login, logout, isClient };
};
