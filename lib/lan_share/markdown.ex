defmodule LanShare.Markdown do
  @moduledoc """
  使用纯 Elixir Markdown 库将消息源码渲染为安全 HTML。
  """

  @options %Earmark.Options{
    breaks: true,
    code_class_prefix: "language-",
    compact_output: true,
    escape: true,
    smartypants: false
  }

  def render(nil), do: ""

  def render(text) when is_binary(text) do
    text
    |> Earmark.as_html!(@options)
    |> HtmlSanitizeEx.markdown_html()
    |> String.trim()
  end
end
