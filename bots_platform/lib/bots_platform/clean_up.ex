defmodule BotsPlatform.FileCleanup do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_), do: {:ok, %{}, {:continue, :schedule}}

  def handle_continue(:schedule, state) do
    schedule_cleanup()
    {:noreply, state}
  end

  def handle_info(:cleanup, state) do
    File.ls!("priv/static/uploads")
    |> Enum.each(fn file ->
      path = Path.join("priv/static/uploads", file)

      if File.stat!(path).mtime < Timex.shift(Timex.now(), days: -7) do
        File.rm!(path)
      end
    end)

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, 24 * 60 * 60 * 1000)
end
