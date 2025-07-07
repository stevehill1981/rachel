import Config

# Set the environment for runtime checks
config :rachel, :env, :test

# Database removed - using in-memory state only

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :rachel, RachelWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "pncmtoU1Ol95xJ6dDEAKOLNCQReMOBICyvcWw2b+ks0DZeT9njfiklJmO5WNbw58",
  server: false

# Mailer removed

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
