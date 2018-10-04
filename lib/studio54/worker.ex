defmodule Studio54.Worker do
  @moduledoc """
    This is the base module
  """
  use GenServer
  require Logger
  alias Studio54.Db, as: Db
  @tick Application.get_env(:studio54, :tick)
  @delay_on_record Application.get_env(:studio54, :delay_on_record)
  # @mo_webhook Application.get_env(:studio54, :mo_webhook)
  # @delivery_webhook Application.get_env(:studio54, :delivery_webhook)
  def start(state) do
    GenServer.start(__MODULE__, state)
  end

  def start_saver(pid) do
    Process.send_after(pid, {:"$gen_cast", {:message_saver, pid}}, 1000)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:message_saver, pid}, state) do
    case Studio54.get_new_count() do
      {:ok, 0} ->
        :continue

      {:ok, n} ->
        {:ok, count, msgs} = Studio54.get_inbox(new: true)

        msgs =
          case n == count do
            true ->
              msgs

            false ->
              # why exit? because probably we have encounterd a situation
              # where we have received a multipart message and it's yet to
              # complete.  so we need to wait a bit more.
              Process.exit(pid, :try_again)
              # Process.sleep(@delay_on_record)
              # {:ok, _count, msgs} = Studio54.get_inbox(new: true)
              # msgs
          end

        joiner = ", "

        Logger.debug(
          "got #{n} new messages from #{
            for x <- msgs do
              x.sender
            end
            |> Enum.join(joiner)
          }."
        )

        msgs
        |> Enum.map(fn m ->
          m.index
        end)
        |> Studio54.mark_as_read()

        msgs
        |> Enum.map(fn m ->
          m.sender
        end)
        |> Enum.uniq()
        |> Enum.map(fn sender ->
          :ok =
            ConCache.put(:message_cache, sender, %ConCache.Item{
              ttl: @delay_on_record,
              value: :ping
            })
        end)
    end

    :ok = Db.retire_expired_message_events()
    [{_, worker_pid}] = Registry.lookup(Studio54.Processes, "worker")
    Process.send_after(worker_pid, {:"$gen_cast", {:message_saver, pid}}, @tick)
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
