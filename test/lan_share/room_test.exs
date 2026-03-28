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
end
