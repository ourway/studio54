defmodule Studio54.Worker do
  @moduledoc """
    This is the base module


  """
  use GenServer
  require Logger
  @tick 1_000
  @mno Application.get_env(:studio54, :mno)
  @mo_webhook Application.get_env(:studio54, :mo_webhook)
  # @delivery_webhook Application.get_env(:studio54, :delivery_webhook)
  def start do
    GenServer.start(__MODULE__, [])
  end

  def get_inbox(pid) do
    GenServer.cast(pid, {:get_inbox})
  end

  def init(args) do
    {:ok, args}
  end

  def handle_cast({:get_inbox}, state) do
    # Logger.debug("reading inbox messages")

    case Studio54.get_new_count() do
      {:ok, 0} ->
        # Logger.debug("no new messages :/")
        :continue

      {:ok, _} ->
        {:ok, _count, msgs} = Studio54.get_inbox(new: true)
        Logger.debug("got #{msgs |> length} new messages.")

        msgs
        |> Enum.map(fn m ->
          m.index
        end)
        |> Studio54.mark_as_read()

        msgs
        |> Enum.map(fn m ->
          HTTPotion.post(@mo_webhook,
            body: m |> Map.put_new(:mno, @mno) |> Poison.encode!(),
            headers: ["Content-Type": "applicaion/json"]
          )
        end)
    end

    Process.send_after(self(), {:"$gen_cast", {:get_inbox}}, @tick)
    {:noreply, state}
  end
end
