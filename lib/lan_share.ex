defmodule LanShare do
  @moduledoc """
  LanShare - 局域网文字图片共享工具。

  启动后，局域网内的设备通过浏览器访问即可互相发送文字和图片。
  无需配对，自动识别设备名称。

  ## 启动

      mix run --no-halt

  或在 iex 中:

      iex -S mix
  """

  @doc "获取本机局域网 IP 地址"
  def local_ip do
    case :inet.getifaddrs() do
      {:ok, ifaddrs} ->
        ifaddrs
        |> Enum.flat_map(fn {_name, opts} ->
          opts
          |> Keyword.get_values(:addr)
          |> Enum.filter(fn
            {a, _, _, _} when a != 127 -> true
            _ -> false
          end)
        end)
        |> List.first()
        |> case do
          nil -> "127.0.0.1"
          ip -> ip |> :inet.ntoa() |> to_string()
        end

      _ ->
        "127.0.0.1"
    end
  end
end
