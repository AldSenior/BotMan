defmodule BotsPlatformWeb.UploadController do
  use BotsPlatformWeb, :controller

  def serve(conn, %{"path" => path}) do
    file_path = Path.join(["priv", "static", "uploads" | path])

    if File.exists?(file_path) do
      send_file(conn, 200, file_path)
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "File not found"})
    end
  end
end
