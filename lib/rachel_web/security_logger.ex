defmodule RachelWeb.SecurityLogger do
  @moduledoc """
  Centralized security event logging for monitoring and alerting.

  This module provides structured logging for security-related events:
  - Authentication attempts
  - Authorization failures  
  - Rate limiting violations
  - Session anomalies
  - Input validation failures
  - Suspicious activity patterns
  """

  require Logger
  alias Phoenix.PubSub

  @security_events_topic "security_events"

  # Event severity levels
  @severity_low 1
  @severity_medium 2
  @severity_high 3
  @severity_critical 4

  @doc """
  Log a security event with structured data for monitoring systems.
  """
  def log_security_event(event_type, severity, metadata \\ %{}) do
    event = %{
      timestamp: DateTime.utc_now(),
      event_type: event_type,
      severity: severity,
      metadata: metadata,
      node: Node.self(),
      environment: Mix.env()
    }

    # Log to standard logger with appropriate level
    log_level = severity_to_log_level(severity)
    Logger.log(log_level, format_security_message(event), event)

    # Broadcast for real-time monitoring (if enabled)
    if monitoring_enabled?() do
      PubSub.broadcast(Rachel.PubSub, @security_events_topic, {:security_event, event})
    end

    # Store in database for analysis (async to avoid blocking)
    if should_persist?(severity) do
      Task.start(fn -> persist_security_event(event) end)
    end

    event
  end

  # Convenience functions for different event types

  @doc "Log authentication-related events"
  def log_auth_event(event_subtype, user_id, metadata \\ %{}) do
    log_security_event(
      :authentication,
      @severity_medium,
      Map.merge(metadata, %{
        subtype: event_subtype,
        user_id: user_id,
        user_agent: Map.get(metadata, :user_agent),
        ip_address: Map.get(metadata, :ip_address)
      })
    )
  end

  @doc "Log authorization failures"
  def log_authorization_failure(resource, user_id, metadata \\ %{}) do
    log_security_event(
      :authorization_failure,
      @severity_high,
      Map.merge(metadata, %{
        resource: resource,
        user_id: user_id,
        attempted_action: Map.get(metadata, :action)
      })
    )
  end

  @doc "Log rate limiting violations"
  def log_rate_limit_violation(player_id, action, metadata \\ %{}) do
    log_security_event(
      :rate_limit_violation,
      @severity_medium,
      Map.merge(metadata, %{
        player_id: player_id,
        action: action,
        current_count: Map.get(metadata, :current_count),
        limit: Map.get(metadata, :limit)
      })
    )
  end

  @doc "Log input validation failures"
  def log_validation_failure(input_type, player_id, metadata \\ %{}) do
    log_security_event(
      :validation_failure,
      @severity_low,
      Map.merge(metadata, %{
        input_type: input_type,
        player_id: player_id,
        invalid_value: sanitize_for_logging(Map.get(metadata, :value)),
        validation_error: Map.get(metadata, :error)
      })
    )
  end

  @doc "Log session security events"
  def log_session_event(event_subtype, session_id, metadata \\ %{}) do
    severity =
      case event_subtype do
        :hijacking_attempt -> @severity_critical
        :fixation_attempt -> @severity_high
        :ip_change -> @severity_medium
        :renewal -> @severity_low
        _ -> @severity_medium
      end

    log_security_event(
      :session_security,
      severity,
      Map.merge(metadata, %{
        subtype: event_subtype,
        session_id: session_id
      })
    )
  end

  @doc "Log suspicious activity patterns"
  def log_suspicious_activity(pattern_type, player_id, metadata \\ %{}) do
    log_security_event(
      :suspicious_activity,
      @severity_high,
      Map.merge(metadata, %{
        pattern: pattern_type,
        player_id: player_id,
        confidence_score: Map.get(metadata, :confidence, 0.5)
      })
    )
  end

  @doc "Log game-specific security events"
  def log_game_security_event(event_subtype, game_id, player_id, metadata \\ %{}) do
    severity =
      case event_subtype do
        :cheating_attempt -> @severity_critical
        :invalid_move -> @severity_medium
        :data_manipulation -> @severity_high
        _ -> @severity_low
      end

    log_security_event(
      :game_security,
      severity,
      Map.merge(metadata, %{
        subtype: event_subtype,
        game_id: game_id,
        player_id: player_id
      })
    )
  end

  # Private helper functions

  defp severity_to_log_level(@severity_low), do: :info
  defp severity_to_log_level(@severity_medium), do: :warning
  defp severity_to_log_level(@severity_high), do: :error
  defp severity_to_log_level(@severity_critical), do: :critical

  defp format_security_message(event) do
    "SECURITY_EVENT[#{event.event_type}] " <>
      "severity=#{event.severity} " <>
      "metadata=#{inspect(event.metadata)}"
  end

  defp monitoring_enabled? do
    Application.get_env(:rachel, :security_monitoring, true)
  end

  defp should_persist?(severity) do
    # Only persist medium and above to avoid log spam
    severity >= @severity_medium
  end

  defp persist_security_event(event) do
    # In a real implementation, you might:
    # - Store in a security_events table
    # - Send to external SIEM system
    # - Queue for batch processing
    # - Send alerts for critical events

    try do
      case event.severity do
        @severity_critical ->
          send_critical_alert(event)

        @severity_high ->
          maybe_send_alert(event)

        _ ->
          :ok
      end
    rescue
      error ->
        Logger.error("Failed to persist security event: #{inspect(error)}")
    end
  end

  defp send_critical_alert(event) do
    # In production, integrate with:
    # - PagerDuty
    # - Slack notifications
    # - Email alerts
    # - SMS alerts
    Logger.critical("🚨 CRITICAL SECURITY EVENT: #{inspect(event)}")
  end

  defp maybe_send_alert(event) do
    # Check if this type of event should trigger an alert
    if should_alert?(event) do
      Logger.error("⚠️ Security Alert: #{inspect(event)}")
    end
  end

  defp should_alert?(event) do
    # Implement logic for when to send alerts
    # - Frequency thresholds
    # - Severity combinations
    # - Time-based rules
    case event.event_type do
      :authorization_failure -> true
      :session_security -> event.metadata.subtype in [:hijacking_attempt, :fixation_attempt]
      :suspicious_activity -> event.metadata.confidence_score > 0.8
      _ -> false
    end
  end

  defp sanitize_for_logging(value) when is_binary(value) do
    # Truncate and sanitize sensitive data for logging
    value
    # Truncate long values
    |> String.slice(0, 100)
    # Replace special chars
    |> String.replace(~r/[^\w\s\-\.]/, "?")
  end

  defp sanitize_for_logging(value), do: inspect(value)

  # Public API for security metrics

  @doc "Get security event counts for monitoring dashboards"
  def get_security_metrics(time_range \\ :last_hour) do
    # In production, this would query the security events table
    # For now, return placeholder data
    %{
      total_events: 0,
      events_by_severity: %{
        low: 0,
        medium: 0,
        high: 0,
        critical: 0
      },
      events_by_type: %{
        authentication: 0,
        authorization_failure: 0,
        rate_limit_violation: 0,
        session_security: 0,
        validation_failure: 0,
        suspicious_activity: 0,
        game_security: 0
      },
      time_range: time_range
    }
  end
end
