defmodule Studio54.Worker do
  @moduledoc """
    This is the base module
  """
  use GenServer
  require Logger
  # @tick 5_000
  @mno Application.get_env(:studio54, :mno)
  @mo_webhook Application.get_env(:studio54, :mo_webhook)
  # @delivery_webhook Application.get_env(:studio54, :delivery_webhook)
  def start(state) do
    GenServer.start(__MODULE__, state)
  end

  def get_inbox(pid, target \\ :any) do
    [{_, worker_pid}] = Registry.lookup(Studio54.Processes, "worker")
    GenServer.cast(worker_pid, {pid, :get_inbox, target})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({pid, :get_inbox, target}, state) do
    msgs =
      case target do
        :any ->
          {:ok, _count, msgs} = Studio54.get_inbox(new: false)
          msgs

        t ->
          Studio54.get_last_n_messages_from(t, 50)
      end

    results =
      case msgs |> length do
        0 ->
          []

        _n ->
          case state.history |> Enum.filter(fn h -> h |> elem(0) == pid end) do
            [] ->
              # send(pid, msgs)
              msgs

            [{_, t}] ->
              msgs
              |> Enum.filter(fn m ->
                m.unixtime - t  >= 0
              end)
          end
      end

    # results
    # |> Enum.map(fn m ->
    #  m.index
    # end)
    # |> Studio54.mark_as_read()

    results
    |> Enum.map(fn m ->
      HTTPotion.post(@mo_webhook,
        body: m |> Map.put_new(:mno, @mno) |> Poison.encode!(),
        headers: ["Content-Type": "applicaion/json"]
      )
    end)

    send(pid, {:ok, results})

    epcho =
      Timex.now()
      |> Timex.to_unix()

    new_state = %{state | history: state.history |> List.keystore(pid, 0, {pid, epcho})}
    # update agent for recovery
    Agent.update(state.state_agent, fn _ -> new_state end)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({_ref, _msg}, state) do
    {:noreply, state}
  end
end
