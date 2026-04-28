defmodule LanShare.FileStoreTest do
  use ExUnit.Case, async: false

  alias LanShare.FileStore

  setup do
    upload_root =
      Path.join(System.tmp_dir!(), "lan_share-file-store-test-#{System.unique_integer([:positive])}")

    previous_root = Application.get_env(:lan_share, :upload_root)
    previous_available_bytes = Application.get_env(:lan_share, :upload_available_bytes_override)

    Application.put_env(:lan_share, :upload_root, upload_root)
    Application.delete_env(:lan_share, :upload_available_bytes_override)

    FileStore.reset()

    on_exit(fn ->
      restore_env(:upload_root, previous_root)
      restore_env(:upload_available_bytes_override, previous_available_bytes)
      FileStore.reset()
      File.rm_rf(upload_root)
    end)

    {:ok, upload_root: upload_root}
  end

  test "delete/2 removes file from disk and clears the metadata index", %{upload_root: upload_root} do
    {:ok, metadata} = FileStore.store_upload(build_upload("a.txt", "alpha"), "AB12")
    file_path = Path.join([upload_root, "AB12", metadata.id])

    assert File.exists?(file_path)
    assert {:ok, _} = FileStore.lookup(metadata.id)

    assert :ok = FileStore.delete(metadata.id, "AB12")

    refute File.exists?(file_path)
    assert :error = FileStore.lookup(metadata.id)
  end

  test "delete/2 refuses to delete when room mismatches" do
    {:ok, metadata} = FileStore.store_upload(build_upload("b.txt", "beta"), "AB12")

    assert {:error, :room_mismatch} = FileStore.delete(metadata.id, "ZZ99")
    assert {:ok, _} = FileStore.lookup(metadata.id)
  end

  test "delete/2 returns :not_found for unknown id" do
    assert {:error, :not_found} = FileStore.delete("missing-id", "AB12")
  end

  test "delete/2 is idempotent if disk file already gone", %{upload_root: upload_root} do
    {:ok, metadata} = FileStore.store_upload(build_upload("c.txt", "gamma"), "AB12")
    file_path = Path.join([upload_root, "AB12", metadata.id])

    File.rm!(file_path)

    assert :ok = FileStore.delete(metadata.id, "AB12")
    assert :error = FileStore.lookup(metadata.id)
  end

  defp build_upload(filename, contents, content_type \\ "text/plain") do
    path = Path.join(System.tmp_dir!(), "lan-share-fs-upload-#{System.unique_integer([:positive])}")
    File.write!(path, contents)
    %Plug.Upload{path: path, filename: filename, content_type: content_type}
  end

  defp restore_env(key, nil), do: Application.delete_env(:lan_share, key)
  defp restore_env(key, value), do: Application.put_env(:lan_share, key, value)
end
