defmodule Studio54Test do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  doctest Studio54
  alias Studio54.Starter, as: Starter
  alias Studio54.Worker, as: Worker
  alias Studio54.Db, as: Db
  alias Studio54.DbSetup, as: DbSetup

  setup_all do
    {status, pid} = Starter.start_link(%{})
    assert status == :ok
    assert is_pid(pid)
    # wait for everything to start
    assert :ok == Studio54.Application.db_setup()
    Process.sleep(1000)
    :ok

    on_exit(fn ->
      {status, result} = Studio54.empty_index()
      assert status == :ok or status == :error
      assert result == true or Regex.match?(~r/\d+/, result)

      [{_, worker_pid}] = Registry.lookup(Studio54.Processes, "worker")
      state = :sys.get_state(pid)
      assert state.worker == worker_pid

      capture_log(fn ->
        Process.exit(worker_pid, :error)
      end) =~ "went down"

      assert :ok == DbSetup.delete_schema()
    end)
  end

  describe "database" do
    test "adding incomming messages is successful" do
      {status, idx} = Db.add_incomming_message("989120228207", "wow, it's a test")
      assert status == :atomic
    end

    test "adding message event working" do
      {:ok, idx} = Db.add_message_event("989120228207", 3, IO, :inspect, "\\d{5}")
      {:atomic, ev} = Db.get_message_event(idx)
      assert elem(ev, 1) == idx
      {:ok, idx} = Db.add_message_event("989120228207", 3, IO, :inspect)
    end

    test "reading messages table is ok" do
      {:atomic, idx} = Db.add_incomming_message("989120228207", "wow, it's second test")
      {:ok, msgs} = Db.read_incomming_messages_from("989120228207")
      {:atomic, msg} = Db.get_message(idx)
      assert elem(msg, 2) =~ "wow"
      assert length(msgs) >= 1
    end

    test "updating message event result is ok" do
      {:atomic, idx} = Db.add_incomming_message("989120228207", "wow, it's second test")
      {:ok, e_idx} = Db.add_message_event("989120228207", 3, IO, :inspect, "\\d{5}")
      assert {:atomic, :ok} == Db.update_message_event_result(e_idx, %{})
      {:atomic, ev} = Db.get_message_event(e_idx)
      assert elem(ev, 11) == %{}
      assert {:atomic, :ok} == Db.update_message_event_message(e_idx, idx)
      {:atomic, ev} = Db.get_message_event(e_idx)
      assert elem(ev, 12) == idx
    end

    test "retiring events works correct" do
      {:ok, e_idx} = Db.add_message_event("989120228207", 300, IO, :inspect, "\\d{5}")
      {:atomic, ev} = Db.get_message_event(e_idx)
      assert elem(ev, 8) == false
      {:atomic, :ok} = Db.retire_message_event(e_idx)
      {:atomic, ev} = Db.get_message_event(e_idx)
      assert elem(ev, 8) == true
      {:ok, e_idx} = Db.add_message_event("989120228207", 1, IO, :inspect, "\\d{5}")
      Process.sleep 2000
      :ok = Db.retire_expired_message_events()
    end
  end

  describe "when application starts -> " do
    test "worker gets inbox correctly" do
      [{_, worker_pid}] = Registry.lookup(Studio54.Processes, "worker")
      #
    end
  end

  describe "general tools -> " do
    test "special hash is correct" do
      target = "c34045c1a1db8d1b3fca8a692198466952daae07eaf6104b4c87ed3b55b6af1b"
      assert Studio54.gethash("cool") == target
    end

    test "fetchig message count is correct" do
      {:ok, new_count} = Studio54.get_new_count()
      assert is_integer(new_count)
    end

    test "msisdn normalization" do
      assert_raise MatchError, fn -> Studio54.normalize_msisdn("") end
      assert Studio54.normalize_msisdn("RighTel") == "rightel"
      assert Studio54.normalize_msisdn(" 989120228207") == "9120228207"
    end
  end

  describe "sms core tools -> " do
    setup do
      :ok
    end

    test "sending sms is successful" do
      message_code = UUID.uuid4()

      {:ok, true} =
        Studio54.send_sms(98_307_000, "test message send from Studio54\n#{message_code}")

      # check the outbox
      {:ok, count, msgs} = Studio54.get_outbox()
      lma = msgs |> List.first()
      lm = Studio54.get_last_message_from(98_307_000)
      assert lm == nil or is_map(lm)
      assert lma == nil or is_map(lma)
      assert is_list(msgs)
      assert is_integer(count)
    end
  end

  describe "USSD tools -> " do
    setup do
      :ok
    end

    test "sending ussd is successful" do
      {:ok, result} = Studio54.send_ussd("*800*1#")
      assert result =~ "مشترک گرامی"
    end
  end
end
