import Config

config :lan_share,
  port: 10086,
  upload_root: "var/uploads",
  message_db_path: "var/lan_share.sqlite3"

if config_env() == :test do
  config :lan_share,
    port: 0
end
