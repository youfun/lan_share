defmodule LanShare.Room do
  @moduledoc """
  房间码的校验、规范化与路径辅助。
  """

  @room_code_regex ~r/^[A-Za-z0-9]{4}$/
  @alphabet "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

  def normalize(nil), do: nil

  def normalize(code) when is_binary(code) do
    normalized =
      code
      |> String.trim()
      |> String.upcase()

    if String.match?(normalized, @room_code_regex), do: normalized, else: nil
  end

  def normalize(_), do: nil

  def valid?(code) do
    not is_nil(normalize(code))
  end

  def generate do
    for _ <- 1..4, into: "" do
      <<String.at(@alphabet, :rand.uniform(String.length(@alphabet)) - 1)::binary>>
    end
  end

  def path(nil), do: "/"
  def path(code), do: "/r/" <> normalize!(code)

  def qrcode_path(code), do: path(code) <> "/qrcode.svg"

  def normalize!(code) do
    case normalize(code) do
      nil -> raise ArgumentError, "invalid room code"
      normalized -> normalized
    end
  end

  def label(nil), do: "大厅"
  def label(code), do: normalize!(code)

  @doc """
  房间模式:
  - `:lan` 仅允许同局域网设备建立 WebRTC DataChannel,VPS 仅做信令转发,不存储/不转发消息内容
  - `:relay` 历史行为,所有内容经服务器转发并持久化
  """
  def default_mode, do: :lan

  def normalize_mode(mode) when mode in [:lan, :relay], do: mode

  def normalize_mode(mode) when is_binary(mode) do
    case String.downcase(String.trim(mode)) do
      "lan" -> :lan
      "relay" -> :relay
      _ -> nil
    end
  end

  def normalize_mode(_), do: nil

  def mode_label(:lan), do: "局域网"
  def mode_label(:relay), do: "中继"
  def mode_label(_), do: "局域网"
end
