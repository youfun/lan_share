defmodule LanShare.RoomQRCode do
  @moduledoc """
  为房间分享链接生成 SVG 二维码。
  """

  alias QRCode.Render.SvgSettings

  @svg_settings %SvgSettings{
    background_color: "#ffffff",
    flatten: true,
    qrcode_color: {7, 94, 84},
    quiet_zone: 2,
    scale: 8,
    structure: :minify
  }

  def svg(url) when is_binary(url) do
    url
    |> QRCode.create(:medium)
    |> QRCode.render(:svg, @svg_settings)
  end
end
