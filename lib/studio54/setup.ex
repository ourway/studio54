defmodule Studio54.DbSetup do
  require Logger

  def delete_schema do
    :stopped = :mnesia.stop()

    case :mnesia.delete_schema([node()]) do
      :ok ->
        Logger.warn("database schema deleted.")
    end

    :ok = :mnesia.start()
  end

  def create_schema do
    :stopped = :mnesia.stop()

    case :mnesia.create_schema([node()]) do
      :ok ->
        Logger.info("database schema created.")

      {:error, {_, {:already_exists, _}}} ->
        Logger.debug("database schema is already created.")
    end

    :ok = :mnesia.start()
  end

  def create_message_table do
    case :mnesia.create_table(Message, [
           {:disc_copies, [node()]},
           attributes: [
             :uuid,
             :body,
             :sender,
             :receiver,
             :unixtime
           ],
           index: [:sender, :receiver]
         ]) do
      {:atomic, :ok} ->
        Logger.info("message table is created.")

      {:aborted, {:already_exists, Message}} ->
        Logger.debug("message table is available.")
    end

    :ok
  end

  def create_message_event_table do
    case :mnesia.create_table(MessageEvent, [
           {:disc_copies, [node()]},
           attributes: [
             :uuid,
             :target,
             :sender,
             :timeout,
             :module,
             :function,
             :status,
             :result,
             :unixtime
           ],
           index: [:target, :sender, :status]
         ]) do
      {:atomic, :ok} ->
        Logger.info("message_event table is created.")

      {:aborted, {:already_exists, MessageEvent}} ->
        Logger.debug("message_event table is available.")
    end

    :ok
  end
end
