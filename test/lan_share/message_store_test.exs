defmodule LanShare.MessageStoreTest do
  use ExUnit.Case, async: false

  alias LanShare.MessageStore

  setup do
    MessageStore.reset()

    on_exit(fn ->
      MessageStore.reset()
    end)

    :ok
  end

  test "file messages use the same 100-message history budget" do
    room_code = "AB12"

    for index <- 1..100 do
      MessageStore.push(room_code, %{type: "text", content: "text-#{index}", room_code: room_code})
    end

    MessageStore.push(room_code, %{
      type: "file",
      id: "file-1",
      filename: "notes.txt",
      size: 12,
      content_type: "text/plain",
      download_url: "/files/file-1?room=AB12",
      room_code: room_code
    })

    history = MessageStore.get_history(room_code)

    assert length(history) == 100
    refute Enum.any?(history, &(&1[:content] == "text-1"))
    assert Enum.any?(history, &(&1.type == "file" and &1.id == "file-1"))
    refute Enum.any?(history, &(Map.has_key?(&1, :data) and &1.type == "file"))
  end
end
