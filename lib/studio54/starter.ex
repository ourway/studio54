defmodule Studio54.Starter do
  @moduledoc """
    This is the base module


  """
  use GenServer
  require Logger
  alias Studio54.Worker
  # @delivery_webhook Application.get_env(:studio54, :delivery_webhook)

  def start_worker do
    GenServer.cast(__MODULE__, {:start_worker})
  end

  def start_link do
    case GenServer.start(__MODULE__, [], name: __MODULE__) do
      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:ok, pid} ->
        {:ok, pid}
    end
  end

  @impl true
  def init(_) do
    {:ok, _} = Registry.start_link(keys: :unique, name: Studio54.Processes)

    start_worker()
    state = %{}
    {:ok, state}
  end

  @impl true
  def handle_cast({:start_worker}, state) do
    {:ok, worker} = Worker.start()
    Logger.info("Studio54 core worker started.")
    Process.monitor(worker)
    Worker.get_inbox(worker)
    :ok = Registry.unregister(Studio54.Processes, "worker")
    {:ok, _} = Registry.register(Studio54.Processes, "worker", worker)
    {:noreply, state |> Map.put(:worker, worker)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _worker, _reason}, state) do
    Logger.warn("Studio54 message core worker went down! Starting again after 5 seconds")
    _time = Process.send_after(self(), {:"$gen_cast", :start_worker}, 5_000)

    {:noreply, state}
  end
end
