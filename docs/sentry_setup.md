# Sentry Error Tracking Setup

This guide explains how to set up Sentry error tracking for Rachel.

## 1. Create a Sentry Account

1. Go to [https://sentry.io](https://sentry.io)
2. Sign up for a free account (up to 5K errors/month free)
3. Create a new project:
   - Platform: Elixir
   - Project name: rachel-production (or similar)

## 2. Get Your DSN

After creating the project, Sentry will show you a DSN (Data Source Name) that looks like:
```
https://abc123@o12345.ingest.sentry.io/67890
```

## 3. Configure Environment Variables

Add the DSN to your production environment:

```bash
# For local testing
export SENTRY_DSN="your-dsn-here"

# For Fly.io deployment
fly secrets set SENTRY_DSN="your-dsn-here"
```

## 4. Features Included

Our Sentry integration includes:

- **Automatic Error Capture**: All unhandled errors are automatically sent to Sentry
- **Sensitive Data Filtering**: The `Rachel.SentryFilter` module prevents sensitive data from being logged:
  - Passwords, tokens, API keys are filtered
  - All cookies are sanitized
  - Session IDs are removed
- **Ignored Errors**: Common non-critical errors are filtered out:
  - 404 errors (NoRouteError)
  - Expected Ecto errors
  - Rate limiting errors
- **Context Enhancement**: Each error includes:
  - Elixir/OTP versions
  - Node information
  - App version
  - Environment (prod/staging)
- **LiveView Integration**: Errors in LiveView processes are captured
- **Source Code Context**: Stack traces include surrounding code

## 5. Testing the Integration

To verify Sentry is working in production:

1. Deploy with the SENTRY_DSN configured
2. Trigger a test error by visiting: `/trigger-test-error` (you'll need to add this route)
3. Check your Sentry dashboard for the error

## 6. CodeCov Integration (Coming Soon)

Sentry can integrate with CodeCov to show code coverage information alongside errors. To enable:

1. Set up CodeCov for the project
2. In Sentry project settings, go to Integrations
3. Enable the CodeCov integration
4. Link your repository

## 7. Performance Monitoring (Optional)

Sentry also offers performance monitoring. To enable:

1. In config/runtime.exs, add:
   ```elixir
   config :sentry,
     # ... existing config ...
     traces_sample_rate: 0.1  # Sample 10% of transactions
   ```

2. This will track:
   - Phoenix request duration
   - Database query performance
   - LiveView mount/update times

## 8. Alerts and Notifications

Configure alerts in Sentry dashboard:

1. Go to Alerts → Create Alert Rule
2. Suggested alerts:
   - Error rate spike (>10 errors in 5 minutes)
   - New error types
   - High error rate for specific pages

## 9. Best Practices

- **Don't Log Sensitive Data**: Our filter handles most cases, but be careful with custom logging
- **Use Sentry.capture_message/2** for important non-error events:
  ```elixir
  Sentry.capture_message("Important event occurred", level: :info)
  ```
- **Add Custom Context** for debugging:
  ```elixir
  Sentry.Context.set_user_context(%{id: user_id, username: username})
  Sentry.Context.set_extra_context(%{game_id: game_id})
  ```

## 10. Monitoring Dashboard

View your errors at: https://sentry.io/organizations/YOUR_ORG/issues/

Key metrics to watch:
- Error rate trends
- Most frequent errors
- Errors by browser/OS
- Performance metrics