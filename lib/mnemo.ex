defmodule Mnemo do
  alias Mnemo.Message

  @type t :: %{
    responsive: boolean, # whether to send out enqueued messages upon receipt of new messages.
    send_queue: queue,
    messages: list(Message.t)
  }
  @type queue :: :queue.queue

  defstruct [send_queue: :queue.new(), messages: [], responsive: false]

  def new, do: %__MODULE__{}

  @spec has_enqueued?(t) :: boolean
  def has_enqueued?(%Mnemo{} = mnemo), do: not :queue.is_empty(mnemo.send_queue)

  @spec has_received_or_sent?(t) :: boolean
  def has_received_or_sent?(%Mnemo{} = mnemo), do: not Enum.empty?(mnemo.messages)

  @spec enqueue_message(t, Message.t) :: t
  def enqueue_message(%__MODULE__{} = mnemo, message), do: Map.put(mnemo, :send_queue, add_to_queue(mnemo.send_queue, message))

  @spec send_enqueued_message(t) :: t
  def send_enqueued_message(%Mnemo{} = mnemo) do
    {to_send, mnemo} = remove_message_from_queue(mnemo)

    mnemo
    |> make_responsive
    |> archive_message(to_send)
  end

  @spec send_message_now(t, Message.t) :: t
  def send_message_now(%Mnemo{} = mnemo, nil), do: mnemo
  def send_message_now(%Mnemo{} = mnemo, message) do
    mnemo
    |> archive_message(message)
  end

  @spec receive_message(t, Message.t) :: t
  def receive_message(%Mnemo{ responsive: false } = mnemo, message) do
    mnemo
    |> archive_message(message)
  end
  def receive_message(%Mnemo{} = mnemo, message) do
    mnemo
    |> archive_message(message)
    |> inform_receipt_to_queued_messages()
    |> send_messages_if_not_pending()
  end

  defp inform_receipt_to_queued_messages(%{ responsive: false } = mnemo), do: mnemo
  defp inform_receipt_to_queued_messages(mnemo) do
    mnemo
    |> Map.update!(:send_queue, fn queue ->
      update_first_in_queue(queue, &Message.ack_receipt/1)
    end)
  end

  @spec send_messages_if_not_pending(t) :: t
  defp send_messages_if_not_pending(%__MODULE__{responsive: true, send_queue: {_, [%Message{listen_for: 0}]}} = mnemo), do: send_enqueued_message(mnemo)
  defp send_messages_if_not_pending(%__MODULE__{responsive: true, send_queue: {[%Message{listen_for: 0}], []}} = mnemo), do: send_enqueued_message(mnemo)
  defp send_messages_if_not_pending(%__MODULE__{} = mnemo), do: mnemo

  @spec update_first_in_queue(queue, (Message.t -> Message.t)) :: queue
  defp update_first_in_queue(queue, func) do
    case :queue.out(queue) do
      {:empty, _} -> queue
      {{:value, first}, new_queue} -> :queue.in_r(func.(first), new_queue)
    end
  end

  @spec make_responsive(t) :: t
  def make_responsive(mnemo), do: Map.put(mnemo, :responsive, true)

  @spec make_unresponsive(t) :: t
  def make_unresponsive(mnemo), do: Map.put(mnemo, :responsive, false)


  @spec remove_message_from_queue(t) :: { any | nil, t }
  defp remove_message_from_queue(mnemo) do
    case :queue.out(mnemo.send_queue) do
      {{:value, val}, new_queue} -> { val, Map.put(mnemo, :send_queue, new_queue) }
      {:empty, _}           -> { nil, mnemo }
    end
  end

  @spec archive_message(t, Message.t | nil) :: t
  defp archive_message(mnemo, nil), do: mnemo
  defp archive_message(mnemo, message) do
    Map.update!(mnemo, :messages, fn messages ->
      add_to_list(messages, message)
    end)
  end


  @spec add_to_queue(queue, any) :: queue
  defp add_to_queue(queue, value), do: :queue.in(value, queue)

  @spec add_to_list(list(), any) :: list()
  defp add_to_list(list, value), do: list ++ [value]

end
