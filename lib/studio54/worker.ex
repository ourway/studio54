defmodule Studio54.Worker do
  @moduledoc """
    This is the base module
  """
  use GenServer
  require Logger
  alias Studio54.Db, as: Db
  @tick 2_000
  # @mno Application.get_env(:studio54, :mno)
  # @mo_webhook Application.get_env(:studio54, :mo_webhook)
  # @delivery_webhook Application.get_env(:studio54, :delivery_webhook)
  def start(state) do
    GenServer.start(__MODULE__, state)
  end

  def get_inbox(sender, target \\ :any, identifier \\ UUID.uuid4()) do
    [{_, worker_pid}] = Registry.lookup(Studio54.Processes, "worker")
    GenServer.cast(worker_pid, {sender, :get_inbox, target, identifier})
  end

  def start_saver(pid) do
    GenServer.cast(pid, {:message_saver})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:message_saver}, state) do
    {:ok, _count, msgs} = Studio54.get_inbox(new: true)

    msgs
    |> Enum.map(fn m ->
      {:atomic, :ok} = Db.add_incomming_message(m.sender, m.body, m.unixtime)
      m
    end)
    |> Enum.map(fn m ->
      m.index
    end)
    |> Studio54.mark_as_read()

    # Db.retire_expired_message_events()

    [{_, worker_pid}] = Registry.lookup(Studio54.Processes, "worker")
    Process.send_after(worker_pid, {:"$gen_cast", {:message_saver}}, @tick)

    {:noreply, state}
  end

  @impl true
  def handle_info({_ref, _msg}, state) do
    {:noreply, state}
  end
end
