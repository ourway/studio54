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
    {:atomic, idx}
  end

  def get_message(idx) do
    case :mnesia.transaction(fn ->
           :mnesia.read(Message, idx)
         end) do
      {:atomic, []} ->
        {:error, :not_found}

      {:atomic, d} ->
        {:atomic, d |> List.first()}
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
           function, false, regex, ret_if_no_match, nil, nil}

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

      {:atomic, d} ->
        {:atomic, d |> List.first()}
    end
  end

  def update_message_event_result(idx, result) do
    {:atomic, mev} = get_message_event(idx)
    pack = mev |> put_elem(11, result)

    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        :ok = :mnesia.write(pack)
      end)
  end

  def update_message_event_message(idx, message_idx) do
    {:atomic, msg} = get_message(message_idx)
    {:atomic, mev} = get_message_event(idx)
    pack = mev |> put_elem(12, msg |> elem(1))

    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        :ok = :mnesia.write(pack)
      end)
  end

  def retire_message_event(idx) do
    {:atomic, mev} = get_message_event(idx)
    pack = mev |> put_elem(8, true)
    Logger.debug("retiring message event: #{idx}")

    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        :ok = :mnesia.write(pack)
      end)
  end

  def get_active_events do
    {:atomic, _events} =
      :mnesia.transaction(fn ->
        :mnesia.index_read(MessageEvent, false, :retired?)
      end)
  end

  @doc "retire message events that has a timeout, not permement and expired."
  def retire_expired_message_events() do
    now = Timex.now() |> Timex.to_unix()

    {:atomic, events} = get_active_events()

    events
    |> Enum.filter(fn me ->
      idx = me |> elem(1)
      now > idx
    end)
    |> Enum.map(fn me ->
      retire_message_event(me |> elem(1))
    end)

    :ok
  end

  def event_process(events, m, idx) do
    events
    |> Enum.filter(fn e ->
      e |> elem(3) == m.sender
    end)
    |> Enum.map(fn e ->
      e_idx = e |> elem(1)
      module = e |> elem(6)
      function = e |> elem(7)
      regex = e |> elem(9)
      ret_if_no_match = e |> elem(10)

      case regex do
        nil ->
          update_message_event_message(e_idx, idx)
          result = apply(module, function, [idx])
          update_message_event_result(e_idx, result)

        r ->
          case Regex.match?(r, m.body) do
            true ->
              update_message_event_message(e_idx, idx)
              result = apply(module, function, [idx])
              update_message_event_result(e_idx, result)

              case ret_if_no_match do
                true ->
                  e_idx |> retire_message_event()

                false ->
                  :continue
              end

            false ->
              :continue
          end
      end
    end)

    :ok
  end
end
