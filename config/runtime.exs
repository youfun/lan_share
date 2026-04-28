import Config

if config_env() == :prod do
  # release 模式下默认把数据放到 release 根目录的 var/ 子目录
  # 即解压后的 lan_share/ 目录里，跟 bin/ 同级
  base_dir = System.get_env("RELEASE_ROOT") || File.cwd!()

  config :lan_share,
    port: String.to_integer(System.get_env("PORT") || "10086"),
    upload_root:
      System.get_env("LAN_SHARE_UPLOAD_ROOT") || Path.join([base_dir, "var", "uploads"]),
    message_db_path:
      System.get_env("LAN_SHARE_DB") || Path.join([base_dir, "var", "lan_share.sqlite3"])
end
