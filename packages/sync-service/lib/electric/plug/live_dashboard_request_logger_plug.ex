defmodule Electric.Plug.LiveDashboardRequestLoggerPlug do
  @moduledoc """
  Streams the sync API's requests to the LiveDashboard "Request Logger" page.

  `Phoenix.LiveDashboard.RequestLogger` signs its stream token with the *endpoint's* secret and
  broadcasts on the endpoint's PubSub, so it expects a Phoenix endpoint in `conn.private`. The sync
  API is a plain `Plug.Router` on Bandit, so this plug lends it the dashboard endpoint for the
  duration of the check. No-op when the dashboard is not enabled (`ELECTRIC_LIVE_DASHBOARD_PORT`).

  Usage from the dashboard: open "Request Logger", copy the `?request_logger=<token>` query
  parameter, append it to any sync API request.
  """

  @behaviour Plug

  @impl Plug
  def init(opts), do: Phoenix.LiveDashboard.RequestLogger.init(opts)

  @impl Plug
  def call(conn, opts) do
    if Electric.Config.get_env(:live_dashboard_port) do
      conn
      |> Plug.Conn.fetch_query_params()
      |> Plug.Conn.put_private(:phoenix_endpoint, Electric.LiveDashboard.Endpoint)
      |> Phoenix.LiveDashboard.RequestLogger.call(opts)
    else
      conn
    end
  end
end
