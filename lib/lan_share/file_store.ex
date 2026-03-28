defmodule LanShare.FileStore do
  @moduledoc """
  Manages room-scoped uploaded files and their in-memory metadata index.
  """
  use GenServer

  require Logger

  @default_upload_root "var/uploads"
  @max_file_size 1_073_741_824

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def max_file_size do
    Application.get_env(:lan_share, :max_file_size, @max_file_size)
  end

  def store_upload(%Plug.Upload{} = upload, room_code) do
    GenServer.call(__MODULE__, {:store_upload, upload, room_code}, :infinity)
  end

  def lookup(file_id) when is_binary(file_id) do
    GenServer.call(__MODULE__, {:lookup, file_id})
  end

  def lookup(_file_id), do: :error

  def download_url(file_id, room_code) do
    "/files/#{file_id}?room=#{room_code}"
  end

  def reset do
    GenServer.call(__MODULE__, :reset, :infinity)
  end

  @impl true
  def init(state) do
    {:ok, ensure_upload_root!(state)}
  end

  @impl true
  def handle_call({:store_upload, upload, room_code}, _from, state) do
    root = upload_root()
    room_dir = Path.join(root, room_code)

    with {:ok, state} <- ensure_upload_root(state),
         :ok <- File.mkdir_p(room_dir),
         {:ok, size} <- file_size(upload.path),
         :ok <- validate_size(size),
         :ok <- ensure_disk_space(root, size),
         {:ok, metadata, state} <- persist_upload(upload, room_code, room_dir, size, state) do
      {:reply, {:ok, public_metadata(metadata)}, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:lookup, file_id}, _from, state) do
    case Map.fetch(state, file_id) do
      {:ok, metadata} -> {:reply, {:ok, metadata}, state}
      :error -> {:reply, :error, state}
    end
  end

  def handle_call(:reset, _from, state) do
    Enum.each(state, fn {_file_id, metadata} ->
      File.rm(metadata.path)
    end)

    root = upload_root()
    File.rm_rf(root)
    {:reply, :ok, ensure_upload_root!(%{})}
  end

  defp persist_upload(upload, room_code, room_dir, size, state) do
    file_id = generate_file_id(state)
    destination = Path.join(room_dir, file_id)
    filename = sanitize_filename(upload.filename)
    content_type = normalize_content_type(upload.content_type)

    metadata = %{
      id: file_id,
      filename: filename,
      size: size,
      content_type: content_type,
      room_code: room_code,
      path: destination
    }

    case move_upload(upload.path, destination) do
      :ok ->
        {:ok, metadata, Map.put(state, file_id, metadata)}

      {:error, reason} ->
        cleanup_partial(destination)
        {:error, reason}
    end
  end

  defp move_upload(source, destination) do
    case File.rename(source, destination) do
      :ok ->
        :ok

      {:error, :exdev} ->
        with :ok <- File.cp(source, destination),
             :ok <- File.rm(source) do
          :ok
        else
          {:error, reason} ->
            cleanup_partial(destination)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cleanup_partial(path) do
    File.rm(path)
    :ok
  end

  defp validate_size(size) do
    if size <= max_file_size(), do: :ok, else: {:error, :file_too_large}
  end

  defp file_size(path) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} -> {:ok, size}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_disk_space(root, size) do
    case available_bytes(root) do
      {:ok, available} when available < size ->
        {:error, :insufficient_disk_space}

      {:ok, _available} ->
        :ok

      {:error, reason} ->
        Logger.warning("Unable to verify upload disk space for #{root}: #{inspect(reason)}")
        :ok
    end
  end

  defp available_bytes(root) do
    case Application.get_env(:lan_share, :upload_available_bytes_override) do
      value when is_integer(value) and value >= 0 ->
        {:ok, value}

      _ ->
        with {:ok, _apps} <- Application.ensure_all_started(:os_mon),
             disks when is_list(disks) <- :disksup.get_disk_data(),
             {:ok, _mount_point, total_kb, used_percent} <- find_disk(root, disks) do
          free_ratio = max(0, 100 - used_percent) / 100
          {:ok, trunc(total_kb * free_ratio) * 1024}
        else
          [] -> {:error, :no_disk_data}
          {:error, reason} -> {:error, reason}
          other -> {:error, other}
        end
    end
  end

  defp find_disk(root, disks) do
    root = Path.expand(root)

    disks
    |> Enum.map(fn {mount, total_kb, used_percent} ->
      {to_string(mount), total_kb, used_percent}
    end)
    |> Enum.filter(fn {mount, _total_kb, _used_percent} ->
      root == mount or String.starts_with?(root, mount <> "/")
    end)
    |> Enum.sort_by(fn {mount, _total_kb, _used_percent} -> String.length(mount) end, :desc)
    |> List.first()
    |> case do
      {mount, total_kb, used_percent} -> {:ok, mount, total_kb, used_percent}
      nil -> {:error, :mount_not_found}
    end
  end

  defp generate_file_id(state) do
    file_id = Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)

    if Map.has_key?(state, file_id) do
      generate_file_id(state)
    else
      file_id
    end
  end

  defp sanitize_filename(filename) when is_binary(filename) do
    filename
    |> String.replace(~r/[\x00-\x1F\x7F]/u, "")
    |> String.split(~r{[\\/]}, trim: true)
    |> List.last()
    |> case do
      nil -> "file"
      "" -> "file"
      sanitized -> sanitized
    end
  end

  defp sanitize_filename(_filename), do: "file"

  defp normalize_content_type(content_type) when is_binary(content_type) and content_type != "",
    do: content_type

  defp normalize_content_type(_content_type), do: "application/octet-stream"

  defp public_metadata(metadata) do
    metadata
    |> Map.take([:id, :filename, :size, :content_type, :room_code])
    |> Map.put(:download_url, download_url(metadata.id, metadata.room_code))
  end

  defp ensure_upload_root(state) do
    root = upload_root()

    case File.mkdir_p(root) do
      :ok -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_upload_root!(state) do
    case ensure_upload_root(state) do
      {:ok, next_state} -> next_state
      {:error, reason} -> raise "failed to prepare upload root: #{inspect(reason)}"
    end
  end

  defp upload_root do
    Application.get_env(:lan_share, :upload_root, @default_upload_root)
    |> Path.expand(File.cwd!())
  end
end
