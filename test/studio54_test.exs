defmodule Studio54Test do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  doctest Studio54
  alias Studio54.Starter, as: Starter
  alias Studio54.Worker, as: Worker

  setup_all do
    {status, pid} = Starter.start_link(%{})
    assert status == :ok
    assert is_pid(pid)
    # wait for everything to start
    # Process.sleep 1000
    :ok

    on_exit(fn ->
      assert {:ok, true} == Studio54.empty_index()

      [{_, worker_pid}] = Registry.lookup(Studio54.Processes, "worker")
      state = :sys.get_state(pid)
      assert state.worker == worker_pid

      capture_log(fn ->
        Process.exit(worker_pid, :error)
      end) =~ "went down"
    end)
  end

  describe "when application starts -> " do
    test "worker gets inbox correctly" do
      Worker.get_inbox(self())
      assert_receive {:ok, message_list}, 5000

      :timer.sleep(500)
      # now get message from a target:
      Worker.get_inbox(self(), 98_307_000)
      assert_receive {:ok, new_message_list}, 5000
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
