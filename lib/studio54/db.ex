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

  def add_incomming_message(sender) do
    Studio54.get_last_n_messages_from(sender, 20)
    |> Enum.map(fn m ->
      idx = "#{m.sender}-#{m.unixtime}-#{m.index}"

      {:atomic, :ok} =
        :mnesia.transaction(fn ->
          pack =
            {Message, idx, m.body, m.sender, @receiver |> Studio54.normalize_msisdn(), m.unixtime}

          :ok = :mnesia.write(pack)
        end)

      {:atomic, events} = get_active_events()
      event_process(events, m, idx)
      Studio54.delete_message(m.index)
      Logger.debug("saved incomming message(s) from #{m.sender}.")
      m.index
    end)

    # |> Studio54.mark_as_read()

    {:atomic, :ok}
  end

  def get_last_message_body_from(sender) do
    get_last_message_from(sender) |> elem(2)
  end

  def get_last_message_from(sender) do
    get_messages_from(sender) |> List.last()
  end

  def get_messages_from(sender) do
    {:atomic, msgs} =
      :mnesia.transaction(fn ->
        :mnesia.index_read(Message, sender, :sender)
      end)

    msgs
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

  @doc """
  Subscribe to an incomming message event.

  Example:

      ```
      iex> Studio54.Db.add_message_event 98912028207, 60, IO, :inspect, "[\\d]{5}", true, []
      {:ok, idx}

      ## with expire call backs:
      iex> Studio54.Db.add_message_event("989120228207", 30, 
        Studio54, :test_func, "pink2", true, [:cool], IO, :inspect, [:oh_sorry])

      ```


  """
  def add_message_event(
        target,
        timeout,
        module,
        function,
        match \\ nil,
        ret_if_no_match \\ true,
        args \\ [],
        timeout_module \\ nil,
        timeout_function \\ nil,
        timeout_args \\ []
      )
      when is_integer(timeout) and timeout > 0 and not is_nil(module) and is_atom(function) and
             is_list(args) and is_list(timeout_args) do
    regex =
      case match do
        nil ->
          nil

        m ->
          {:ok, pat} = Regex.compile(m)
          pat
      end

    now = Timex.now() |> Timex.to_unix()
    idx = "#{now + timeout}-#{UUID.uuid4()}"

    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        pack =
          {MessageEvent, idx, now, target |> Studio54.normalize_msisdn(), self(), timeout, module,
           function, false, regex, ret_if_no_match, nil, nil, args, timeout_module,
           timeout_function, timeout_args}

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

  def is_active_event(idx) do
    {:atomic, mev} = get_message_event(idx)

    elem(mev, 8) == false
  end

  def retire_message_event(idx) do
    {:atomic, mev} = get_message_event(idx)

    case is_active_event(idx) do
      true ->
        pack = mev |> put_elem(8, true)
        Logger.debug("retiring message event: #{idx}")

        {:atomic, :ok} =
          :mnesia.transaction(fn ->
            :ok = :mnesia.write(pack)
          end)

      false ->
        {:atomic, :ok}
    end
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
      timeout = me |> elem(5)
      unixtime = me |> elem(2)
      now > timeout + unixtime
    end)
    |> Enum.map(fn me ->
      timeout_module = me |> elem(14)
      timeout_function = me |> elem(15)
      timeout_args = me |> elem(16)

      try do
        if timeout_module != nil and timeout_function != nil do
          apply(timeout_module, timeout_function, timeout_args)
        end
      rescue
        e ->
          IO.inspect(e)
      end

      retire_message_event(me |> elem(1))
    end)

    :ok
  end

  def event_process(events, m, idx) do
    {:atomic, message} = idx |> get_message

    events
    |> Enum.filter(fn e ->
      e |> elem(3) == m.sender and is_active_event(e |> elem(1)) == true
    end)
    |> Enum.map(fn e ->
      e_idx = e |> elem(1)
      module = e |> elem(6)
      function = e |> elem(7)
      args = e |> elem(13)

      regex = e |> elem(9)
      ret_if_no_match = e |> elem(10)

      case regex do
        nil ->
          update_message_event_message(e_idx, idx)

          result =
            try do
              apply(module, function, args ++ [message])
            rescue
              e ->
                e
            end

          update_message_event_result(e_idx, result)
          e_idx |> retire_message_event()

        r ->
          case Regex.match?(r, m.body) do
            true ->
              update_message_event_message(e_idx, idx)
              result = apply(module, function, args ++ [message])
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
