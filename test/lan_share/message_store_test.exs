defmodule LanShare.MessageStoreTest do
  use ExUnit.Case, async: false

  alias LanShare.MessageStore

  setup do
    previous_db_path = Application.get_env(:lan_share, :message_db_path)
    MessageStore.reset()

    on_exit(fn ->
      restore_env(:message_db_path, previous_db_path)
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

  test "delete/2 removes a message by id and leaves others untouched" do
    room_code = "AB12"

    MessageStore.push(room_code, %{
      id: "msg-1",
      type: "text",
      sender: "Alice",
      content: "first",
      room_code: room_code
    })

    MessageStore.push(room_code, %{
      id: "msg-2",
      type: "text",
      sender: "Bob",
      content: "second",
      room_code: room_code
    })

    assert {:ok, deleted} = MessageStore.delete(room_code, "msg-1")
    assert deleted.id == "msg-1"
    assert deleted.sender == "Alice"

    history = MessageStore.get_history(room_code)
    assert Enum.map(history, & &1.id) == ["msg-2"]
  end

  test "delete/2 returns :not_found for unknown id" do
    assert {:error, :not_found} = MessageStore.delete("AB12", "missing")
  end

  test "lookup/2 returns the stored message by id" do
    MessageStore.push("AB12", %{
      id: "look-1",
      type: "text",
      sender: "Alice",
      content: "lookup me",
      room_code: "AB12"
    })

    assert {:ok, msg} = MessageStore.lookup("AB12", "look-1")
    assert msg.sender == "Alice"
    assert msg.content == "lookup me"
  end

  test "lookup/2 returns :error for unknown id" do
    assert :error = MessageStore.lookup("AB12", "no-such-id")
  end

  test "delete/2 only matches within the requested room" do
    MessageStore.push("AB12", %{
      id: "shared-id",
      type: "text",
      sender: "Alice",
      content: "in AB12",
      room_code: "AB12"
    })

    assert {:error, :not_found} = MessageStore.delete("CD34", "shared-id")
    assert [%{id: "shared-id"}] = MessageStore.get_history("AB12")
  end

  test "history survives message store restart when sqlite file is configured" do
    db_path =
      Path.join(
        System.tmp_dir!(),
        "lan-share-message-store-#{System.unique_integer([:positive])}.sqlite3"
      )

    previous_db_path = Application.get_env(:lan_share, :message_db_path)

    Application.put_env(:lan_share, :message_db_path, db_path)
    restart_message_store()

    MessageStore.push("AB12", %{type: "text", content: "persisted", room_code: "AB12"})

    restart_message_store()

    history = MessageStore.get_history("AB12")

    assert Enum.any?(history, &(&1.type == "text" and &1.content == "persisted"))

    restore_env(:message_db_path, previous_db_path)
    restart_message_store()
    File.rm(db_path)
    File.rm(db_path <> "-wal")
    File.rm(db_path <> "-shm")
  end

  defp restart_message_store do
    pid = Process.whereis(MessageStore)

    if pid do
      GenServer.stop(pid, :normal, 5_000)
      wait_until_started(pid)
    end

    :ok
  end

  defp wait_until_started(previous_pid) do
    Enum.reduce_while(1..50, :ok, fn _, _acc ->
      case Process.whereis(MessageStore) do
        nil ->
          Process.sleep(20)
          {:cont, :ok}

        ^previous_pid ->
          Process.sleep(20)
          {:cont, :ok}

        _new_pid ->
          {:halt, :ok}
      end
    end)
  end

  defp restore_env(key, nil), do: Application.delete_env(:lan_share, key)
  defp restore_env(key, value), do: Application.put_env(:lan_share, key, value)
end
