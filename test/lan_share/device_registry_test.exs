defmodule LanShare.DeviceRegistryTest do
  use ExUnit.Case, async: false

  alias LanShare.DeviceRegistry

  setup do
    on_exit(fn -> DeviceRegistry.reset() end)
    DeviceRegistry.reset()
    :ok
  end

  test "room creator is the first device that registers in that room" do
    pid1 = spawn_idle()
    pid2 = spawn_idle()

    DeviceRegistry.register(pid1, "Alice", "AB12")
    DeviceRegistry.register(pid2, "Bob", "AB12")

    assert DeviceRegistry.room_creator("AB12") == "Alice"
  end

  test "room creator persists after the creator leaves" do
    pid1 = spawn_idle()
    DeviceRegistry.register(pid1, "Alice", "CD34")

    Process.exit(pid1, :kill)
    wait_until(fn -> DeviceRegistry.list_devices("CD34") == [] end)

    assert DeviceRegistry.room_creator("CD34") == "Alice"
  end

  test "different rooms have independent creators" do
    pid1 = spawn_idle()
    pid2 = spawn_idle()

    DeviceRegistry.register(pid1, "Alice", "AA11")
    DeviceRegistry.register(pid2, "Bob", "BB22")

    assert DeviceRegistry.room_creator("AA11") == "Alice"
    assert DeviceRegistry.room_creator("BB22") == "Bob"
  end

  test "lobby (nil) tracks its own creator" do
    pid1 = spawn_idle()
    DeviceRegistry.register(pid1, "Alice", nil)

    assert DeviceRegistry.room_creator(nil) == "Alice"
  end

  test "room_creator returns nil for unknown rooms" do
    assert DeviceRegistry.room_creator("ZZ99") == nil
  end

  describe "mode" do
    test "register/3 defaults the room to :lan mode" do
      pid = spawn_idle()
      {:ok, _peer_id, mode} = DeviceRegistry.register(pid, "Alice", "AB12")

      assert mode == :lan
      assert DeviceRegistry.room_mode("AB12") == :lan
    end

    test "register/4 sets room mode on first registration" do
      pid = spawn_idle()
      {:ok, _peer_id, mode} = DeviceRegistry.register(pid, "Alice", "RL01", :relay)

      assert mode == :relay
      assert DeviceRegistry.room_mode("RL01") == :relay
    end

    test "later registrations cannot change room mode" do
      pid1 = spawn_idle()
      pid2 = spawn_idle()

      {:ok, _, :relay} = DeviceRegistry.register(pid1, "Alice", "RL02", :relay)
      {:ok, _, mode_for_bob} = DeviceRegistry.register(pid2, "Bob", "RL02", :lan)

      assert mode_for_bob == :relay
      assert DeviceRegistry.room_mode("RL02") == :relay
    end

    test "room_mode returns :lan for unknown rooms" do
      assert DeviceRegistry.room_mode("ZZ99") == :lan
    end

    test "lobby (room_code nil) is always :relay regardless of requested mode" do
      pid1 = spawn_idle()
      {:ok, _peer1, mode1} = DeviceRegistry.register(pid1, "Alice", nil, :lan)

      assert mode1 == :relay
      assert DeviceRegistry.room_mode(nil) == :relay

      pid2 = spawn_idle()
      {:ok, _peer2, mode2} = DeviceRegistry.register(pid2, "Bob", nil, :relay)
      assert mode2 == :relay
    end

    test "lobby stays :relay even when first registered without explicit mode" do
      pid = spawn_idle()
      {:ok, _peer, mode} = DeviceRegistry.register(pid, "Alice", nil)

      assert mode == :relay
      assert DeviceRegistry.room_mode(nil) == :relay
    end
  end

  describe "peer ids" do
    test "register/3 returns a unique peer_id per pid" do
      pid1 = spawn_idle()
      pid2 = spawn_idle()

      {:ok, peer1, _} = DeviceRegistry.register(pid1, "Alice", "PR01")
      {:ok, peer2, _} = DeviceRegistry.register(pid2, "Bob", "PR01")

      assert is_binary(peer1)
      assert is_binary(peer2)
      assert peer1 != peer2
    end

    test "list_peers returns id+name pairs scoped to a room" do
      pid1 = spawn_idle()
      pid2 = spawn_idle()
      pid3 = spawn_idle()

      {:ok, peer1, _} = DeviceRegistry.register(pid1, "Alice", "PL01")
      {:ok, peer2, _} = DeviceRegistry.register(pid2, "Bob", "PL01")
      {:ok, _peer3, _} = DeviceRegistry.register(pid3, "Carol", "PL02")

      peers = DeviceRegistry.list_peers("PL01")

      assert length(peers) == 2
      assert Enum.any?(peers, &(&1.id == peer1 and &1.name == "Alice"))
      assert Enum.any?(peers, &(&1.id == peer2 and &1.name == "Bob"))
    end

    test "peer_pid resolves a peer_id to its pid within a room" do
      pid = spawn_idle()
      {:ok, peer_id, _} = DeviceRegistry.register(pid, "Alice", "PI01")

      assert DeviceRegistry.peer_pid("PI01", peer_id) == pid
      assert DeviceRegistry.peer_pid("PI01", "missing") == nil
      assert DeviceRegistry.peer_pid("OTHER", peer_id) == nil
    end
  end

  defp spawn_idle do
    spawn(fn -> Process.sleep(:infinity) end)
  end

  defp wait_until(fun) do
    Enum.reduce_while(1..100, :ok, fn _i, _acc ->
      if fun.() do
        {:halt, :ok}
      else
        Process.sleep(10)
        {:cont, :ok}
      end
    end)
  end
end
