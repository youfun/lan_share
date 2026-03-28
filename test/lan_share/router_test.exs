defmodule LanShare.RouterTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Plug.Test

  alias LanShare.Router

  test "GET / renders lobby page" do
    conn = conn(:get, "/") |> Router.call([])

    assert conn.status == 200
    assert conn.resp_body =~ "当前会话"
    assert conn.resp_body =~ "大厅"
  end

  test "GET /r/:code renders room page with normalized code" do
    conn = conn(:get, "/r/ab12") |> Router.call([])

    assert conn.status == 200
    assert conn.resp_body =~ "AB12"
    assert conn.resp_body =~ "当前房间链接可扫码分享"
  end

  test "GET /r/:code rejects invalid room code" do
    conn = conn(:get, "/r/abc") |> Router.call([])

    assert conn.status == 400
    assert conn.resp_body =~ "无效房间码"
  end

  test "POST /join redirects to normalized room path" do
    conn = conn(:post, "/join", %{code: "x9y2"}) |> Router.call([])

    assert conn.status == 302
    assert get_resp_header(conn, "location") == ["/r/X9Y2"]
  end

  test "POST /join rejects malformed room code" do
    conn = conn(:post, "/join", %{code: "12-3"}) |> Router.call([])

    assert conn.status == 400
    assert conn.resp_body =~ "房间码必须为 4 位字母或数字"
  end

  test "GET /room/new redirects to a valid room path" do
    conn = conn(:get, "/room/new") |> Router.call([])
    [location] = get_resp_header(conn, "location")

    assert conn.status == 302
    assert location =~ ~r|^/r/[A-Z0-9]{4}$|
  end
end
