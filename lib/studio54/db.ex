defmodule Studio54.Db do
  require Logger
  @receiver Application.get_env(:studio54, :msisdn)

  def set_state(state) do
    # Logger.debug("studio54 state updated in database.")

    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        pack = {Studio54WorkerState, :data, state}
        :ok = :mnesia.write(pack)
      end)
  end

  def get_state do
    case :mnesia.transaction(fn ->
           :mnesia.read(Studio54WorkerState, :data)
         end) do
      {:atomic, [{Studio54WorkerState, :data, state}]} ->
        {:ok, state}

      {:atomic, []} ->
        {:error, :not_found}
    end
  end

  def add_incomming_message(sender, body, unixtime \\ Timex.now() |> Timex.to_unix()) do
    idx = "#{unixtime}-#{sender}"

    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        pack =
          {Message, idx, body, sender |> Studio54.normalize_msisdn(),
           @receiver |> Studio54.normalize_msisdn(), unixtime}

        :ok = :mnesia.write(pack)
      end)

    Logger.debug("Added incomming message from #{idx} to database.")
    {:atomic, :ok}
  end



  def get_message(idx) do
    case :mnesia.transaction(fn ->
           :mnesia.read(Message, idx)
         end) do
      {:atomic, []} ->
        {:error, :not_found}

      d ->
        d
    end
  end

  def read_incomming_messages_from(sender) do
    {:atomic, msgs} =
      :mnesia.transaction(fn ->
        :mnesia.index_read(Message, sender |> Studio54.normalize_msisdn(), :sender)
      end)

    {:ok, msgs}
  end

  def add_message_event(
        target,
        timeout,
        module,
        function,
        match \\ nil,
        permenent \\ nil,
        ret_if_no_match \\ true
      )
      when is_integer(timeout) and timeout > 0 and not is_nil(module) and not is_nil(function) do
    regex =
      case match do
        nil ->
          nil

        m ->
          {:ok, pat} = Regex.compile(m)
          pat
      end

    now = Timex.now() |> Timex.to_unix()
    idx = now + timeout

    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        pack =
          {MessageEvent, idx, now, target |> Studio54.normalize_msisdn(), self(), timeout, module,
           function, false, regex, ret_if_no_match, permenent, nil}

        :ok = :mnesia.write(pack)
      end)

    {:ok, idx}
  end

  def get_message_event(idx) do
    case :mnesia.transaction(fn ->
           :mnesia.read(MessageEvent, idx)
         end) do
      {:atomic, []} ->
        {:error, :not_found}

      d ->
        d
    end
  end


  def update_message_event_result(idx, message_idx) do


  end

  @doc "retire message events that has a timeout, not permement and expired."
  def retire_expired_message_events() do
    now = Timex.now() |> Timex.to_unix()

    {:atomic, events} =
      :mnesia.transaction(fn ->
        :mnesia.index_read(MessageEvent, false, :retired?)
      end)
      |> Enum.filter(fn me ->
        timeout = me |> elem(5)
        unixtime = me |> elem(2)

        case timeout do
          nil ->
            false

          to ->
            now - unixtime <= to
        end
      end)
      |> Enum.map(fn me ->
        # NOTE
        case me |> elem(11) do
          false ->
            :not_implemented

          true ->
            {:error, :permenent}
        end
      end)
  end
end
