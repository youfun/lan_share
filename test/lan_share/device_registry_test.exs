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
