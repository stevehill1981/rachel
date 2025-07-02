defmodule Rachel.Repo do
  use Ecto.Repo,
    otp_app: :rachel,
    adapter: Ecto.Adapters.Postgres
end
