defmodule RachelWeb.UserSessionHTML do
  use RachelWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:rachel, Rachel.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
