defmodule Mnemo.Message do

  @type t :: %{
    listen_for: integer, #number of messages to receive while enqueued before message is sent out.
    content: any,
  }

  defstruct [listen_for: 0, content: nil]

  def new(params \\ %{}), do: struct(__MODULE__, params)

  def ack_receipt(message), do: Map.update!(message, :listen_for, &(max(&1 - 1, 0)))

 end
