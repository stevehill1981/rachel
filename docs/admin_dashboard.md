# Admin Dashboard

Rachel includes a simple admin monitoring dashboard for production monitoring.

## Accessing the Dashboard

**URL**: `/admin`

**Default Credentials**:
- Username: `admin`
- Password: `rachel_admin_2024`

⚠️ **IMPORTANT**: Change these credentials in production!

## Setting Custom Credentials

Set environment variables before deploying:

```bash
# For local development
export ADMIN_USERNAME="your_username"
export ADMIN_PASSWORD="your_secure_password"

# For Fly.io deployment
fly secrets set ADMIN_USERNAME="your_username"
fly secrets set ADMIN_PASSWORD="your_secure_password"
```

## Features

### Real-time Metrics
- **Active Games**: Current number of running games
- **Connected Players**: Total players across all games
- **Memory Usage**: Current RAM usage and percentage
- **Process Count**: Erlang process count

### System Information
- **App Version**: Current deployed version
- **Node Name**: Erlang node identifier
- **Uptime**: How long the server has been running
- **Database Stats**: Total games recorded

### Rate Limiter Stats
- **Tracked Keys**: Number of IPs/players being rate limited
- **Memory Usage**: Rate limiter memory consumption

### Active Games Table
Shows all currently active games with:
- Game ID
- Status (waiting/playing/finished)
- Player names and count
- Current player's turn
- Start time
- Stop button for emergency game termination

## Auto-refresh

The dashboard automatically refreshes every 5 seconds to show real-time data. You can also click "Refresh Now" for immediate updates.

## Security

The dashboard is protected by HTTP Basic Authentication. The browser will prompt for credentials on first access.

## Monitoring Best Practices

1. **Memory Usage**: Keep below 80% (800MB) for optimal performance
2. **Process Count**: Normal range is 100-500 processes
3. **Active Games**: Monitor for stuck games (same current player for long time)
4. **Rate Limiter**: High tracked keys might indicate attack

## Emergency Actions

### Stop a Game
Click the "Stop" button next to any game to immediately terminate it. This will:
- Disconnect all players
- Free up resources
- Remove the game from the registry

Use this sparingly as it disrupts player experience.

## Integration with Monitoring

The dashboard complements other monitoring tools:
- **Sentry**: For error tracking
- **Fly.io Dashboard**: For infrastructure metrics
- **Health Endpoints**: For automated monitoring

## Troubleshooting

### Can't Access Dashboard
1. Check credentials are correct
2. Verify the server is running
3. Check logs for authentication errors

### Missing Data
1. Ensure database is connected
2. Check for JavaScript errors in browser console
3. Verify WebSocket connection is established

### High Memory Usage
1. Check number of active games
2. Look for games with many players
3. Monitor rate limiter memory usage
4. Consider restarting if memory leak suspected