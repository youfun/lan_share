defmodule LanShare.MarkdownTest do
  use ExUnit.Case, async: true

  alias LanShare.Markdown

  test "renders common markdown syntax to html" do
    html = Markdown.render("# 标题\n\n- one\n- two\n\n`code`")

    assert html =~ "<h1>标题</h1>"
    assert html =~ "<li>one</li>"
    assert html =~ "<code class=\"inline\">code</code>"
  end

  test "escapes raw html tags" do
    html = Markdown.render("<script>alert('x')</script>")

    assert html == "alert('x')"
    refute html =~ "<script>"
  end
end
