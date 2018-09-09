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
    GenServer.start(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    Process.send_after(self(), :start_worker, 500)
    state = %{}
    {:ok, state}
  end

  @impl true
  def handle_cast({:start_worker}, state) do
    {:ok, worker} = Worker.start()
    Logger.info("Worker Started watching for messages.")
    Process.monitor(worker)
    Worker.get_inbox(worker)

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _worker, _reason}, state) do
    Logger.warn("Worker went down! Starting again after 3 seconds")
    :timer.sleep(3_000)
    start_worker()
    {:noreply, state}
  end

  @impl true
  def handle_info(:start_worker, %{}) do
    start_worker()
    {:noreply, %{}}
  end
end
