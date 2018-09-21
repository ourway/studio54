defmodule Studio54.Db do
  require Logger
  @receiver Application.get_env(:studio54, :msisdn)

  def add_incomming_message(sender, body, unixtime \\ Timex.now() |> Timex.to_unix()) do
    idx = UUID.uuid4()

    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        pack =
          {Message, idx, body, sender |> Studio54.normalize_msisdn(),
           @receiver |> Studio54.normalize_msisdn(), unixtime}

        :ok = :mnesia.write(pack)
      end)

    Logger.debug("Added incomming message #{idx} to database.")
    {:atomic, :ok}
  end

  def read_incomming_messages_from(sender) do
    {:atomic, msgs} =
      :mnesia.transaction(fn ->
        :mnesia.index_read(Message, sender |> Studio54.normalize_msisdn(), :sender)
      end)

    {:ok, msgs}
  end

  def retire_expired_message_events() do
    now = Timex.now() |> Timex.to_unix()

    {:atomix, events} =
      :mnesia.trasaction(fn ->
        :mnesia.index_read(MessageEvent, true, :status)
      end)
  end
end
