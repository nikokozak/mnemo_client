defmodule Mnemo do
  alias Mnemo.Message

  @type t :: %{
    responsive: boolean, # whether to send out enqueued messages upon receipt of new messages.
    to_send: queue,
    messages: list(Message.t)
  }
  @type queue :: :queue.queue

  defstruct [to_send: :queue.new(), messages: [], responsive: false]

  def new, do: %__MODULE__{}

  @spec schedule(t, Message.t) :: t
  def schedule(%__MODULE__{} = mnemo, message) do
    mnemo
    |> Map.put(:to_send, enqueue_message(mnemo.to_send, message))
  end

  @spec send_message(t) :: t
  def send_message(mnemo) do
    {to_send, mnemo} = dequeue_message(mnemo)

    mnemo
    |> make_responsive
    |> archive_message(to_send)
  end

  @spec receive_message(t, Message.t) :: t
  def receive_message(mnemo, message) do
    mnemo
    |> archive_message(message)
    |> inform_receipt()
    |> send_messages_if_not_pending()
  end

  def inform_receipt(mnemo) do
    mnemo
    |> Map.update!(:to_send, fn queue ->
      update_first_in_queue(queue, &Message.ack_receipt/1)
    end)
  end

  def send_messages_if_not_pending(%__MODULE__{responsive: true, to_send: {_, [%Message{listen_for: 0}]}} = mnemo), do: send_message(mnemo)
  def send_messages_if_not_pending(%__MODULE__{responsive: true, to_send: {[%Message{listen_for: 0}], []}} = mnemo), do: send_message(mnemo)
  def send_messages_if_not_pending(%__MODULE__{} = mnemo), do: mnemo

  @spec update_first_in_queue(queue, (Message.t -> Message.t)) :: queue
  defp update_first_in_queue({_, []} = queue, _), do: queue
  defp update_first_in_queue({[_first], []} = queue, func), do: do_update_first_in_queue(queue, func)
  defp update_first_in_queue({_, [_first]} = queue, func), do: do_update_first_in_queue(queue, func)

  defp do_update_first_in_queue(queue, func) do
    {{:value, first}, queue} = :queue.out(queue)
    :queue.in_r(func.(first), queue)
  end

  @spec make_responsive(t) :: t
  defp make_responsive(mnemo), do: Map.put(mnemo, :responsive, true)

  @spec enqueue_message(queue, any) :: queue
  defp enqueue_message(queue, message), do: :queue.in(message, queue)

  @spec dequeue_message(t) :: { any | nil, t }
  defp dequeue_message(mnemo) do
    case :queue.out(mnemo.to_send) do
      {{:value, val}, new_queue} -> { val, Map.put(mnemo, :to_send, new_queue) }
      {:empty, _}           -> { nil, mnemo }
    end
  end

  defp archive_message(mnemo, nil), do: mnemo
  defp archive_message(mnemo, message) do
    Map.update!(mnemo, :messages, fn messages ->
      add_message_to_list(messages, message)
    end)
  end

  @spec add_message_to_list(list(), any) :: list()
  defp add_message_to_list(message_list, message), do: message_list ++ [message]

end
