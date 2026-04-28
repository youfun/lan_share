defmodule LanShare.MessageStore do
  @moduledoc """
  使用 SQLite 持久化最近的消息历史，供新加入的设备查看。
  默认每个房间保留最近 100 条，服务重启后仍可恢复。
  """
  use GenServer

  alias Exqlite.Sqlite3

  @max_messages 100
  @default_db_path "var/lan_share.sqlite3"
  @lobby_room_code "_LOBBY"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "添加一条消息到历史"
  def push(room_code, message) do
    GenServer.cast(__MODULE__, {:push, room_code, message})
  end

  @doc "获取所有历史消息"
  def get_history(room_code) do
    GenServer.call(__MODULE__, {:get_history, room_code})
  end

  @doc "清空所有消息历史"
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @doc """
  根据消息 id 删除某房间内的一条消息。

  返回 `{:ok, message}` 表示删除成功并返回原消息（用于级联清理文件等），
  返回 `{:error, :not_found}` 表示该房间不存在该 id 的消息。
  """
  def delete(room_code, message_id) when is_binary(message_id) do
    GenServer.call(__MODULE__, {:delete, room_code, message_id})
  end

  @doc """
  根据消息 id 查找某房间内的一条消息，未命中返回 `:error`。
  """
  def lookup(room_code, message_id) when is_binary(message_id) do
    GenServer.call(__MODULE__, {:lookup, room_code, message_id})
  end

  # --- 回调 ---

  @impl true
  def init(_) do
    with {:ok, db_path} <- ensure_db_path(message_db_path()),
         {:ok, conn} <- Sqlite3.open(db_path),
         :ok <- configure_database(conn),
         :ok <- ensure_schema(conn) do
      {:ok, %{conn: conn}}
    else
      {:error, reason} -> {:stop, {:sqlite_init_failed, reason}}
    end
  end

  @impl true
  def handle_cast({:push, room_code, message}, state) do
    room_key = storage_room_code(room_code)
    :ok = insert_message(state.conn, room_key, message)
    :ok = trim_history(state.conn, room_key)
    {:noreply, state}
  end

  @impl true
  def handle_call({:get_history, room_code}, _from, state) do
    history = fetch_history(state.conn, storage_room_code(room_code))
    {:reply, history, state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    :ok = clear_history(state.conn)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete, room_code, message_id}, _from, state) do
    room_key = storage_room_code(room_code)

    case find_message_row(state.conn, room_key, message_id) do
      {:ok, db_id, message} ->
        :ok = delete_message_by_db_id(state.conn, db_id)
        {:reply, {:ok, message}, state}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:lookup, room_code, message_id}, _from, state) do
    case find_message_row(state.conn, storage_room_code(room_code), message_id) do
      {:ok, _db_id, message} -> {:reply, {:ok, message}, state}
      :error -> {:reply, :error, state}
    end
  end

  @impl true
  def terminate(_reason, %{conn: conn}) do
    Sqlite3.close(conn)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp message_db_path do
    case Application.get_env(:lan_share, :message_db_path, @default_db_path) do
      ":memory:" -> ":memory:"
      path -> Path.expand(path, File.cwd!())
    end
  end

  defp ensure_db_path(":memory:"), do: {:ok, ":memory:"}

  defp ensure_db_path(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p()
    |> case do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp configure_database(conn) do
    Sqlite3.execute(conn, """
    PRAGMA journal_mode = WAL;
    PRAGMA synchronous = NORMAL;
    PRAGMA busy_timeout = 5000;
    """)
  end

  defp ensure_schema(conn) do
    Sqlite3.execute(conn, """
    CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_code TEXT NOT NULL,
      payload TEXT NOT NULL,
      inserted_at TEXT NOT NULL
    );

    CREATE INDEX IF NOT EXISTS messages_room_code_id_idx
      ON messages(room_code, id);
    """)
  end

  defp insert_message(conn, room_code, message) do
    payload = Jason.encode!(message)

    prepared_step(
      conn,
      """
      INSERT INTO messages (room_code, payload, inserted_at)
      VALUES (?, ?, ?)
      """,
      [room_code, payload, DateTime.utc_now() |> DateTime.to_iso8601()]
    )
  end

  defp trim_history(conn, room_code) do
    prepared_step(
      conn,
      """
      DELETE FROM messages
      WHERE room_code = ?
        AND id NOT IN (
          SELECT id
          FROM messages
          WHERE room_code = ?
          ORDER BY id DESC
          LIMIT ?
        )
      """,
      [room_code, room_code, @max_messages]
    )
  end

  defp fetch_history(conn, room_code) do
    prepared_fetch_all(
      conn,
      """
      SELECT payload
      FROM messages
      WHERE room_code = ?
      ORDER BY id ASC
      """,
      [room_code]
    )
    |> Enum.map(fn [payload] -> Jason.decode!(payload, keys: :atoms!) end)
  end

  defp clear_history(conn) do
    prepared_step(conn, "DELETE FROM messages", [])
  end

  defp find_message_row(conn, room_code, message_id) do
    conn
    |> prepared_fetch_all(
      """
      SELECT id, payload
      FROM messages
      WHERE room_code = ?
      """,
      [room_code]
    )
    |> Enum.find_value(:error, fn [db_id, payload] ->
      msg = Jason.decode!(payload, keys: :atoms!)

      if Map.get(msg, :id) == message_id do
        {:ok, db_id, msg}
      else
        nil
      end
    end)
  end

  defp delete_message_by_db_id(conn, db_id) do
    prepared_step(conn, "DELETE FROM messages WHERE id = ?", [db_id])
  end

  defp storage_room_code(nil), do: @lobby_room_code
  defp storage_room_code(room_code), do: room_code

  defp prepared_step(conn, sql, params) do
    with {:ok, statement} <- Sqlite3.prepare(conn, sql) do
      try do
        :ok = Sqlite3.bind(statement, params)

        case Sqlite3.step(conn, statement) do
          :done -> :ok
          {:error, reason} -> raise "sqlite step failed: #{inspect(reason)}"
          other -> raise "unexpected sqlite result: #{inspect(other)}"
        end
      after
        Sqlite3.release(conn, statement)
      end
    else
      {:error, reason} -> raise "sqlite prepare failed: #{inspect(reason)}"
    end
  end

  defp prepared_fetch_all(conn, sql, params) do
    with {:ok, statement} <- Sqlite3.prepare(conn, sql) do
      try do
        :ok = Sqlite3.bind(statement, params)

        case Sqlite3.fetch_all(conn, statement) do
          {:ok, rows} -> rows
          {:error, reason} -> raise "sqlite fetch failed: #{inspect(reason)}"
        end
      after
        Sqlite3.release(conn, statement)
      end
    else
      {:error, reason} -> raise "sqlite prepare failed: #{inspect(reason)}"
    end
  end
end
