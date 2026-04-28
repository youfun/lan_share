defmodule LanShare.WebSocketTest do
  use ExUnit.Case, async: true

  alias LanShare.WebSocket

  describe "authorized_to_delete?/3" do
    test "sender can delete their own message" do
      msg = %{sender: "Alice"}
      assert WebSocket.authorized_to_delete?(msg, "Alice", "Bob")
    end

    test "room creator can delete other people's messages" do
      msg = %{sender: "Alice"}
      assert WebSocket.authorized_to_delete?(msg, "Bob", "Bob")
    end

    test "stranger cannot delete others' messages" do
      msg = %{sender: "Alice"}
      refute WebSocket.authorized_to_delete?(msg, "Charlie", "Bob")
    end

    test "works with string-keyed messages too" do
      msg = %{"sender" => "Alice"}
      assert WebSocket.authorized_to_delete?(msg, "Alice", "Bob")
    end

    test "if there is no creator yet, only sender can delete" do
      msg = %{sender: "Alice"}
      assert WebSocket.authorized_to_delete?(msg, "Alice", nil)
      refute WebSocket.authorized_to_delete?(msg, "Bob", nil)
    end
  end
end
