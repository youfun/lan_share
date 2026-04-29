defmodule LanShare.RoomTest do
  use ExUnit.Case, async: true

  alias LanShare.Room

  test "normalizes room codes to uppercase" do
    assert Room.normalize("ab12") == "AB12"
    assert Room.normalize("  z9x8  ") == "Z9X8"
  end

  test "rejects invalid room codes" do
    refute Room.valid?("abc")
    refute Room.valid?("abcde")
    refute Room.valid?("ab-1")
    refute Room.valid?("")
  end

  test "generates a valid 4-character room code" do
    code = Room.generate()

    assert code =~ ~r/^[A-Z0-9]{4}$/
    assert Room.valid?(code)
  end

  describe "mode" do
    test "default_mode is :lan" do
      assert Room.default_mode() == :lan
    end

    test "normalize_mode accepts atoms and strings" do
      assert Room.normalize_mode(:lan) == :lan
      assert Room.normalize_mode(:relay) == :relay
      assert Room.normalize_mode("lan") == :lan
      assert Room.normalize_mode("LAN") == :lan
      assert Room.normalize_mode(" relay ") == :relay
    end

    test "normalize_mode rejects invalid values" do
      assert Room.normalize_mode(nil) == nil
      assert Room.normalize_mode("") == nil
      assert Room.normalize_mode("p2p") == nil
      assert Room.normalize_mode(:other) == nil
      assert Room.normalize_mode(123) == nil
    end

    test "mode_label returns Chinese label" do
      assert Room.mode_label(:lan) == "局域网"
      assert Room.mode_label(:relay) == "中继"
    end
  end
end
