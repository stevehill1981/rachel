#!/bin/bash
# Run all quality checks locally

set -e

echo "🔍 Running code quality checks..."

echo "📝 Checking code formatting..."
mix format --check-formatted

echo "🧪 Running tests..."
mix test

echo "🔎 Running Credo..."
mix credo --strict || true

echo "🔬 Running Dialyzer..."
mix dialyzer || true

echo "🔒 Running security checks..."
mix sobelow || true

echo "📦 Checking for unused dependencies..."
mix deps.unlock --check-unused

echo "🚨 Auditing dependencies..."
mix deps.audit || true

echo "✅ All checks complete!"