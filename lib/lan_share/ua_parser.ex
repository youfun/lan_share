defmodule LanShare.UAParser do
  @moduledoc """
  从 User-Agent 字符串中提取可读的设备名称。
  不依赖外部库，使用简单的正则匹配。

  示例输出:
  - "iPhone (Safari)"
  - "Samsung Galaxy (Chrome)"
  - "Windows PC (Chrome)"
  - "MacBook (Safari)"
  - "Linux (Firefox)"
  """

  @doc "从 UA 字符串提取设备名称"
  def parse(nil), do: "未知设备"
  def parse(""), do: "未知设备"

  def parse(ua) when is_binary(ua) do
    device = extract_device(ua)
    browser = extract_browser(ua)

    case {device, browser} do
      {nil, nil} -> "未知设备"
      {nil, b} -> b
      {d, nil} -> d
      {d, b} -> "#{d} (#{b})"
    end
  end

  defp extract_device(ua) do
    cond do
      ua =~ ~r/iPhone/ -> "iPhone"
      ua =~ ~r/iPad/ -> "iPad"
      ua =~ ~r/Android/ -> extract_android_device(ua)
      ua =~ ~r/Macintosh/ -> "Mac"
      ua =~ ~r/Windows/ -> "Windows PC"
      ua =~ ~r/Linux/ -> "Linux"
      ua =~ ~r/CrOS/ -> "Chromebook"
      true -> nil
    end
  end

  defp extract_android_device(ua) do
    case Regex.run(~r/Android[^;]*;\s*([^)]+)\)/, ua) do
      [_, model] ->
        model
        |> String.split(~r/\s+Build/)
        |> List.first()
        |> String.trim()

      _ ->
        "Android"
    end
  end

  defp extract_browser(ua) do
    cond do
      ua =~ ~r/Edg\// -> "Edge"
      ua =~ ~r/OPR\// or ua =~ ~r/Opera/ -> "Opera"
      ua =~ ~r/Chrome\// and not (ua =~ ~r/Edg\//) -> "Chrome"
      ua =~ ~r/Firefox\// -> "Firefox"
      ua =~ ~r/Safari\// and not (ua =~ ~r/Chrome\//) -> "Safari"
      true -> nil
    end
  end
end
