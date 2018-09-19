defmodule Studio54Test do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  doctest Studio54
  alias Studio54.Starter, as: Starter
  alias Studio54.Worker, as: Worker

  setup_all do
    {status, pid} = Starter.start_link()
    assert status == :ok
    assert is_pid(pid)
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
    test "message core worker starts successfully" do
      {status, pid} = Worker.start()
      assert status == :ok
      assert is_pid(pid)
      send(pid, {:"$gen_cast", {:get_inbox}})
    end
  end

  describe "general tools -> " do
    test "special hash is correct" do
      target = "c34045c1a1db8d1b3fca8a692198466952daae07eaf6104b4c87ed3b55b6af1b"
      assert Studio54.gethash("cool") == target
    end

    test "msisdn normalization" do
      assert_raise MatchError, fn -> Studio54.normalize_msisdn("") end
      assert Studio54.normalize_msisdn("RighTel") == "rightel"
      assert Studio54.normalize_msisdn(" 989120228207") == "9120228207"
    end
  end

  describe "sms core tools -> " do
    setup do
      {:ok, pid} = Starter.start_link()
      assert Process.alive?(pid)
      :ok
    end

    test "sending sms is successful" do
      message_code = UUID.uuid4()

      {:ok, true} =
        Studio54.send_sms(989_120_228_207, "test message send from Studio54\n#{message_code}")

      # wait for 1000 mili sec
      Process.sleep(1000)
      # check the outbox
      {:ok, _count, msgs} = Studio54.get_box(2)
      last_message_in_outbox = msgs |> List.first()
      assert last_message_in_outbox.body =~ message_code
      msc1 = UUID.uuid4()
      msc2 = UUID.uuid4()
      Studio54.send_sms(989_120_228_207, "test message send from Studio54\n#{msc1}")
      Studio54.send_sms(989_120_228_207, "test message send from Studio54\n#{msc2}")
      Process.sleep(2000)
      {:ok, count, _msgs} = Studio54.get_box(2)
      assert count >= 2
    end
  end

  describe "USSD tools -> " do
    setup do
      {:ok, pid} = Starter.start_link()
      assert Process.alive?(pid)
      :ok
    end

    test "sending ussd is sucessful" do
      {:ok, result} = Studio54.send_ussd("*800*1#")
      assert result =~ "مشترک گرامی"
      Process.sleep(5000)
      lm = Studio54.get_last_message_from("800")
      target1 = "مشترک گرامی\n"
      assert lm.body =~ target1
      target2 = "سرویس"
      assert lm.body =~ target2
      target3 = "فعال"
      assert lm.body =~ target3
    end
  end
end
