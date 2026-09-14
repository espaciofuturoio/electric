defmodule Electric.LiveDashboard.Telemetry do
  @moduledoc """
  Metrics for the LiveDashboard "Metrics" page, and the poller that feeds them when no exporter
  (StatsD / Prometheus / OTel) is configured.

  The dashboard renders `Telemetry.Metrics` definitions as live charts. Electric already defines
  its application metrics (`ElectricTelemetry.ApplicationTelemetry`) and stack metrics
  (`ElectricTelemetry.StackTelemetry`); this module reuses both, plus the BEAM basics, so the
  dashboard shows the same numbers an exporter would. `ElectricTelemetry.ApplicationTelemetry`
  only starts its periodic poller when an exporter is enabled, so the dashboard starts its own
  otherwise (same measurements, same period) — the point-in-time metrics would stay empty without it.
  """

  import Telemetry.Metrics

  @app_env_key :live_dashboard_telemetry_opts

  @doc "Called by the router's `live_dashboard ... metrics: __MODULE__`."
  def metrics do
    vm_metrics() ++ electric_metrics(telemetry_opts())
  end

  @doc """
  Child specs the dashboard needs besides the endpoint: a poller for the periodic measurements
  when `ElectricTelemetry.ApplicationTelemetry` does not run one itself.
  """
  def children do
    case telemetry_opts() do
      nil ->
        [{:telemetry_poller, measurements: vm_measurements(), period: 10_000, name: __MODULE__.Poller}]

      opts ->
        if ElectricTelemetry.export_enabled?(opts) do
          []
        else
          measurements =
            ElectricTelemetry.Poller.periodic_measurements(opts, ElectricTelemetry.ApplicationTelemetry)

          [
            {:telemetry_poller,
             measurements: measurements,
             period: opts.intervals_and_thresholds.system_metrics_poll_interval,
             init_delay: :timer.seconds(5),
             name: __MODULE__.Poller}
          ]
        end
    end
  end

  @doc "Stores the validated telemetry options for `metrics/0` and `children/0`."
  def put_telemetry_opts(opts) do
    if Code.ensure_loaded?(ElectricTelemetry) do
      case ElectricTelemetry.validate_options(opts) do
        {:ok, validated} -> Application.put_env(:electric, @app_env_key, validated)
        _ -> :ok
      end
    end

    :ok
  end

  defp telemetry_opts, do: Application.get_env(:electric, @app_env_key)

  defp vm_measurements, do: [:memory, :total_run_queue_lengths, :system_counts]

  defp vm_metrics do
    [
      summary("vm.memory.total", unit: {:byte, :megabyte}),
      summary("vm.memory.processes", unit: {:byte, :megabyte}),
      summary("vm.memory.binary", unit: {:byte, :megabyte}),
      summary("vm.memory.ets", unit: {:byte, :megabyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),
      last_value("vm.system_counts.process_count"),
      last_value("vm.system_counts.port_count")
    ]
  end

  defp electric_metrics(nil), do: []

  defp electric_metrics(opts) do
    if Code.ensure_loaded?(ElectricTelemetry.ApplicationTelemetry) do
      # Stack metrics are defined per stack (`keep_for_stack`); this process serves one stack.
      stack_opts = Map.put(opts, :stack_id, Electric.Config.get_env(:provided_database_id))

      ElectricTelemetry.ApplicationTelemetry.metrics(opts) ++
        ElectricTelemetry.StackTelemetry.metrics(stack_opts)
    else
      []
    end
  end
end
