"use client";
import "./globals.css";
import NavMenu from "./components/NavMenu";
import { useAuth } from "./hooks/useAuth";
import { ApolloProvider } from "@apollo/client";
import { createApolloClient } from "./lib/apollo-client";

export default function RootLayout({ children }) {
  const client = createApolloClient();

  return (
    <html lang="en">
      <body>
        <ApolloProvider client={client}>
          <div className="min-h-screen w-[100vw] flex flex-col text-white">
            <NavMenu />
            <main className="flex-1">{children}</main>
          </div>
        </ApolloProvider>
      </body>
    </html>
  );
}
