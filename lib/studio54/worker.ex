defmodule Studio54.Worker do
  @moduledoc """
    This is the base module
  """
  use GenServer
  require Logger
  alias Studio54.Db, as: Db
  @tick Application.get_env(:studio54, :tick)
  # @mo_webhook Application.get_env(:studio54, :mo_webhook)
  # @delivery_webhook Application.get_env(:studio54, :delivery_webhook)
  def start(state) do
    GenServer.start(__MODULE__, state)
  end

  def start_saver(pid) do
    Process.send_after(pid, {:"$gen_cast", {:message_saver}}, @tick)
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
      {:atomic, events} = Db.get_active_events()
      {:atomic, idx} = Db.add_incomming_message(m.sender, m.body, m.unixtime)

      Task.start_link(fn ->
        Db.event_process(events, m, idx)
      end)

      m
    end)
    |> Enum.map(fn m ->
      m.index
    end)
    |> Studio54.mark_as_read()

    Task.start_link(fn ->
      Db.retire_expired_message_events()
    end)

    [{_, worker_pid}] = Registry.lookup(Studio54.Processes, "worker")
    Process.send_after(worker_pid, {:"$gen_cast", {:message_saver}}, @tick)

    Db.set_state(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({_ref, _msg}, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_, state) do
    Db.set_state(state)
  end
end
