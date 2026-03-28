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
end
