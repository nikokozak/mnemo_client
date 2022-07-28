defmodule MnemoTest do
  use ExUnit.Case
  alias Mnemo.Message

  setup do
    blank_mnemo = Mnemo.new()
    {:ok, mnemo: blank_mnemo}
  end

  test "new/0 returns a new Mnemo struct" do
    assert %{ send_queue: {[], []}, messages: [], responsive: false } = Mnemo.new()
  end

  test "enqueue_message/2 correctly enqueues a message", %{ mnemo: mnemo } do
    message_1 = Message.new(%{ content: "one" })
    message_2 = Message.new(%{ content: "two" })

    assert %{ send_queue: {[^message_1], []} } = mnemo = Mnemo.enqueue_message(mnemo, message_1)
    assert %{ send_queue: {[^message_2], [^message_1]} } = Mnemo.enqueue_message(mnemo, message_2)
  end

  describe "send_enqueued_message/1" do
    test "sends enqueued message", %{mnemo: mnemo} do
       message = Message.new(%{ content: "hey" })
       mnemo = Mnemo.enqueue_message(mnemo, message)

       assert %{ send_queue: {[], []}, messages: [^message] } = Mnemo.send_enqueued_message(mnemo)
    end

    test "does not change state if no messages are enqueued", %{mnemo: mnemo} do
      assert %{ send_queue: {[], []}, messages: [] } = Mnemo.send_enqueued_message(mnemo)
    end
  end

  test "send_message_now/2 adds a message to the messages archive without enqueueing it", %{mnemo: mnemo} do
       message = Message.new(%{ content: "hey" })

       assert %{ send_queue: {[], []}, messages: [^message] } = Mnemo.send_message_now(mnemo, message)
  end

  test "mnemo automatically becomes responsive after sending out queued message", %{mnemo: mnemo} do
    assert %{ responsive: false } = mnemo

    mnemo =
      mnemo
      |> Mnemo.enqueue_message(Message.new(%{ content: "one", listen_for: 2 }))
      |> Mnemo.send_enqueued_message()

    assert %{ responsive: true } = mnemo
  end

  describe "receive_message/2" do
    test "places a message in the archive", %{mnemo: mnemo} do
      message = Message.new(%{ content: "hey" })

      assert %{ send_queue: {[], []}, messages: [^message] } = Mnemo.receive_message(mnemo, message)
    end

    test "reduces listen_for count on latest queued message if mnemo is responsive", %{mnemo: mnemo} do
      mnemo =
        mnemo
        |> Mnemo.make_responsive()
        |> Mnemo.enqueue_message(Message.new(%{ content: "one", listen_for: 2 }))
        |> Mnemo.enqueue_message(Message.new(%{ content: "two", listen_for: 2 }))

      mnemo = Mnemo.receive_message(mnemo, Message.new(%{ content: "received" }))

      assert %{ send_queue: {[%{ content: "two", listen_for: 2 }], [%{ content: "one", listen_for: 1 }]} } = mnemo
    end

    test "if listen_for is zero on a queued messages, sends it out on receipt of message", %{mnemo: mnemo} do
      mnemo =
        mnemo
        |> Mnemo.make_responsive()
        |> Mnemo.enqueue_message(Message.new(%{ content: "one", listen_for: 2 }))
        |> Mnemo.enqueue_message(Message.new(%{ content: "two", listen_for: 2 }))

      mnemo = Mnemo.receive_message(mnemo, Message.new(%{ content: "received" }))

      assert %{ send_queue: {[%{ content: "two", listen_for: 2 }], [%{ content: "one", listen_for: 1 }]} } = mnemo

      mnemo = Mnemo.receive_message(mnemo, Message.new(%{ content: "received again" }))

      assert %{ send_queue:
                {[], [%{ content: "two", listen_for: 2 }]},
                messages:
                [%{ content: "received" }, %{content: "received again"}, %{content: "one", listen_for: 0}]
              } = mnemo
    end

    test "receives a message without notifying queued messages if mnemo is unresponsive", %{mnemo: mnemo} do
      mnemo =
        mnemo
        |> Mnemo.enqueue_message(Message.new(%{ content: "one", listen_for: 2 }))
        |> Mnemo.enqueue_message(Message.new(%{ content: "two", listen_for: 2 }))

      assert %{ responsive: false } = mnemo

      mnemo = Mnemo.receive_message(mnemo, Message.new(%{ content: "received" }))

      assert %{ send_queue: {[%{ content: "two", listen_for: 2 }], [%{ content: "one", listen_for: 2 }]} } = mnemo

      mnemo = Mnemo.receive_message(mnemo, Message.new(%{ content: "another" }))

      assert %{ send_queue: {[%{ content: "two", listen_for: 2 }], [%{ content: "one", listen_for: 2 }]}, messages: messages } = mnemo

      assert length(messages) == 2
    end
  end
end
