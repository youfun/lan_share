defmodule LanShareTest do
  use ExUnit.Case
  doctest LanShare

  test "local_ip returns a printable address" do
    ip = LanShare.local_ip()

    assert is_binary(ip)
    assert ip != ""
  end

  test "parses common user agents" do
    assert LanShare.UAParser.parse("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1") ==
             "iPhone (Safari)"

    assert LanShare.UAParser.parse("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36") ==
             "Windows PC (Chrome)"
  end
end
