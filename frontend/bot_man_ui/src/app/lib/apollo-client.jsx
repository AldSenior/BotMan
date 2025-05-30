import { ApolloClient, InMemoryCache, HttpLink } from "@apollo/client";
import { WebSocketLink } from "@apollo/client/link/ws";
import { split, ApolloLink } from "@apollo/client";
import { getMainDefinition } from "@apollo/client/utilities";

export const createApolloClient = (token = "") => {
  console.log("Creating ApolloClient with token:", token);

  const httpLink = new HttpLink({
    uri: "http://localhost:4000/api/graphql",
  });

  const wsLink =
    typeof window !== "undefined"
      ? new WebSocketLink({
          uri: "ws://localhost:4000/socket",
          options: {
            reconnect: true,
            connectionParams: () => ({
              authToken: token || localStorage.getItem("authToken") || "",
            }),
          },
        })
      : null;

  const splitLink =
    typeof window !== "undefined" && wsLink
      ? split(
          ({ query }) => {
            const definition = getMainDefinition(query);
            return (
              definition.kind === "OperationDefinition" &&
              definition.operation === "subscription"
            );
          },
          wsLink,
          httpLink,
        )
      : httpLink;

  const authLink = new ApolloLink((operation, forward) => {
    operation.setContext({
      headers: {
        authorization: token ? `Bearer ${token}` : "",
      },
    });
    return forward(operation);
  });

  return new ApolloClient({
    link: authLink.concat(splitLink),
    cache: new InMemoryCache({
      typePolicies: {
        Query: {
          fields: {
            me: {
              merge(existing, incoming) {
                return incoming;
              },
            },
            bots: {
              merge(existing = [], incoming) {
                return incoming;
              },
            },
          },
        },
      },
    }),
    ssrMode: typeof window === "undefined",
  });
};
