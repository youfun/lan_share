import Config

config :lan_share,
  port: 10086,
  upload_root: "var/uploads"

if config_env() == :test do
  config :lan_share,
    port: 0
end
