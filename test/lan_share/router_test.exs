defmodule LanShare.RouterTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  import Plug.Test

  alias LanShare.Router

  setup do
    upload_root =
      Path.join(System.tmp_dir!(), "lan_share-router-test-#{System.unique_integer([:positive])}")

    previous_root = Application.get_env(:lan_share, :upload_root)
    previous_max_file_size = Application.get_env(:lan_share, :max_file_size)
    previous_available_bytes = Application.get_env(:lan_share, :upload_available_bytes_override)

    Application.put_env(:lan_share, :upload_root, upload_root)
    Application.delete_env(:lan_share, :max_file_size)
    Application.delete_env(:lan_share, :upload_available_bytes_override)

    LanShare.FileStore.reset()
    LanShare.MessageStore.reset()

    on_exit(fn ->
      restore_env(:upload_root, previous_root)
      restore_env(:max_file_size, previous_max_file_size)
      restore_env(:upload_available_bytes_override, previous_available_bytes)
      LanShare.FileStore.reset()
      LanShare.MessageStore.reset()
      File.rm_rf(upload_root)
    end)

    :ok
  end

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

  test "GET /r/:code/qrcode.svg returns svg" do
    conn = conn(:get, "/r/ab12/qrcode.svg") |> Map.put(:host, "127.0.0.1") |> Router.call([])

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["image/svg+xml; charset=utf-8"]
    assert conn.resp_body =~ "<svg"
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

  test "POST /upload/file stores a room-scoped file and returns metadata" do
    upload = build_upload("notes.txt", "hello file transfer")

    conn =
      conn_with_params(:post, "/upload/file", %{"room" => "ab12", "file" => upload})
      |> Router.call([])

    payload = Jason.decode!(conn.resp_body)

    assert conn.status == 200
    assert payload["filename"] == "notes.txt"
    assert payload["room_code"] == "AB12"
    assert payload["size"] == byte_size("hello file transfer")
    assert payload["content_type"] == "text/plain"
    assert payload["download_url"] == "/files/#{payload["id"]}?room=AB12"

    assert File.exists?(
             Path.join([Application.get_env(:lan_share, :upload_root), "AB12", payload["id"]])
           )
  end

  test "POST /upload/file rejects missing file" do
    conn =
      conn_with_params(:post, "/upload/file", %{"room" => "AB12"})
      |> Router.call([])

    assert conn.status == 400
    assert Jason.decode!(conn.resp_body)["error"] =~ "未找到文件"
  end

  test "POST /upload/file rejects invalid room" do
    upload = build_upload("notes.txt", "room check")

    conn =
      conn_with_params(:post, "/upload/file", %{"room" => "bad", "file" => upload})
      |> Router.call([])

    assert conn.status == 400
    assert Jason.decode!(conn.resp_body)["error"] =~ "房间码必须为 4 位字母或数字"
  end

  test "POST /upload/file rejects oversized file" do
    Application.put_env(:lan_share, :max_file_size, 3)
    upload = build_upload("big.txt", "oversized")

    conn =
      conn_with_params(:post, "/upload/file", %{"room" => "AB12", "file" => upload})
      |> Router.call([])

    assert conn.status == 413
    assert Jason.decode!(conn.resp_body)["error"] =~ "文件大小不能超过 1GB"
  end

  test "POST /upload/file rejects when disk space is insufficient" do
    Application.put_env(:lan_share, :upload_available_bytes_override, 1)
    upload = build_upload("notes.txt", "hello")

    conn =
      conn_with_params(:post, "/upload/file", %{"room" => "AB12", "file" => upload})
      |> Router.call([])

    assert conn.status == 507
    assert Jason.decode!(conn.resp_body)["error"] =~ "磁盘剩余空间不足"
  end

  test "GET /files/:id downloads a file for the matching room" do
    upload = build_upload("report.txt", "download me")

    upload_conn =
      conn_with_params(:post, "/upload/file", %{"room" => "AB12", "file" => upload})
      |> Router.call([])

    file_id = Jason.decode!(upload_conn.resp_body)["id"]

    conn = conn(:get, "/files/#{file_id}?room=AB12") |> Router.call([])

    assert conn.status == 200
    assert conn.resp_body == "download me"
    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]

    assert Enum.any?(
             get_resp_header(conn, "content-disposition"),
             &String.contains?(&1, "report.txt")
           )
  end

  test "GET /files/:id rejects a wrong room" do
    upload = build_upload("report.txt", "private file")

    upload_conn =
      conn_with_params(:post, "/upload/file", %{"room" => "AB12", "file" => upload})
      |> Router.call([])

    file_id = Jason.decode!(upload_conn.resp_body)["id"]
    conn = conn(:get, "/files/#{file_id}?room=ZZ99") |> Router.call([])

    assert conn.status == 403
    assert Jason.decode!(conn.resp_body)["error"] =~ "无权访问该文件"
  end

  test "GET /files/:id returns 404 when the stored file is missing" do
    upload = build_upload("report.txt", "gone")

    upload_conn =
      conn_with_params(:post, "/upload/file", %{"room" => "AB12", "file" => upload})
      |> Router.call([])

    file_id = Jason.decode!(upload_conn.resp_body)["id"]
    {:ok, metadata} = LanShare.FileStore.lookup(file_id)
    File.rm!(metadata.path)

    conn = conn(:get, "/files/#{file_id}?room=AB12") |> Router.call([])

    assert conn.status == 404
    assert Jason.decode!(conn.resp_body)["error"] =~ "文件不存在"
  end

  defp conn_with_params(method, path, params) do
    conn(method, path)
    |> Map.put(:body_params, params)
    |> Map.put(:params, params)
  end

  defp build_upload(filename, contents, content_type \\ "text/plain") do
    path = Path.join(System.tmp_dir!(), "lan-share-upload-#{System.unique_integer([:positive])}")
    File.write!(path, contents)
    %Plug.Upload{path: path, filename: filename, content_type: content_type}
  end

  defp restore_env(key, nil), do: Application.delete_env(:lan_share, key)
  defp restore_env(key, value), do: Application.put_env(:lan_share, key, value)
end
