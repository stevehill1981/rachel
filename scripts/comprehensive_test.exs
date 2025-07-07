#!/usr/bin/env elixir

defmodule ComprehensiveTest do
  @moduledoc """
  Comprehensive testing script to catch bugs before production.
  """

  def run do
    IO.puts("🧪 Running Comprehensive Bug Detection")
    IO.puts("=====================================")
    
    results = [
      check_tests(),
      check_coverage(),
      check_code_quality(),
      check_security(),
      check_performance(),
      check_liveview_issues()
    ]
    
    summarize_results(results)
  end
  
  defp check_tests do
    IO.puts("\n1. 🧪 Running Test Suite...")
    case System.cmd("mix", ["test", "--warnings-as-errors"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("✅ All tests pass")
        {:tests, :pass, "All tests passing"}
      {output, _} ->
        IO.puts("❌ Tests failed")
        IO.puts(String.slice(output, 0, 500) <> "...")
        {:tests, :fail, "Tests failing"}
    end
  end
  
  defp check_coverage do
    IO.puts("\n2. 📊 Checking Test Coverage...")
    case System.cmd("mix", ["test", "--cover"], stderr_to_stdout: true) do
      {output, 0} ->
        # Extract coverage percentage
        coverage = extract_coverage(output)
        if coverage >= 80 do
          IO.puts("✅ Coverage: #{coverage}% (target: 80%)")
          {:coverage, :pass, "#{coverage}% coverage"}
        else
          IO.puts("⚠️ Coverage: #{coverage}% (below 80% target)")
          {:coverage, :warn, "#{coverage}% coverage (low)"}
        end
      {_, _} ->
        {:coverage, :fail, "Coverage check failed"}
    end
  end
  
  defp check_code_quality do
    IO.puts("\n3. 🔍 Running Code Quality Checks...")
    
    # Run Credo
    credo_result = case System.cmd("mix", ["credo", "--strict"], stderr_to_stdout: true) do
      {_, 0} -> :pass
      {_, _} -> :warn
    end
    
    # Run Dialyzer (if available)
    dialyzer_result = case System.cmd("mix", ["dialyzer"], stderr_to_stdout: true) do
      {_, 0} -> :pass
      {_, _} -> :warn
    end
    
    if credo_result == :pass and dialyzer_result == :pass do
      IO.puts("✅ Code quality checks pass")
      {:quality, :pass, "Credo and Dialyzer clean"}
    else
      IO.puts("⚠️ Code quality issues found")
      {:quality, :warn, "Quality issues detected"}
    end
  end
  
  defp check_security do
    IO.puts("\n4. 🔒 Running Security Checks...")
    case System.cmd("mix", ["sobelow"], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts("✅ No security vulnerabilities")
        {:security, :pass, "No vulnerabilities"}
      {_, _} ->
        IO.puts("⚠️ Security issues found")
        {:security, :warn, "Security vulnerabilities detected"}
    end
  end
  
  defp check_performance do
    IO.puts("\n5. ⚡ Performance Checks...")
    # Check for common performance issues
    issues = []
    
    # Check for N+1 queries (simple grep)
    case System.cmd("grep", ["-r", "Enum.map.*Repo", "lib/"], stderr_to_stdout: true) do
      {output, 0} when byte_size(output) > 0 ->
        issues = ["Potential N+1 queries found" | issues]
      _ -> :ok
    end
    
    if issues == [] do
      IO.puts("✅ No obvious performance issues")
      {:performance, :pass, "No performance issues"}
    else
      IO.puts("⚠️ Performance issues: #{Enum.join(issues, ", ")}")
      {:performance, :warn, Enum.join(issues, ", ")}
    end
  end
  
  defp check_liveview_issues do
    IO.puts("\n6. 🔄 LiveView Specific Checks...")
    
    # Check for duplicate IDs in tests
    case System.cmd("mix", ["test"], stderr_to_stdout: true) do
      {output, _} ->
        duplicate_warnings = output
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "Duplicate id found"))
        |> length()
        
        if duplicate_warnings > 0 do
          IO.puts("❌ #{duplicate_warnings} duplicate ID warnings (causes DOM bugs)")
          {:liveview, :fail, "#{duplicate_warnings} duplicate IDs"}
        else
          IO.puts("✅ No LiveView DOM issues")
          {:liveview, :pass, "No DOM issues"}
        end
    end
  end
  
  defp extract_coverage(output) do
    case Regex.run(~r/\[TOTAL\]\s+(\d+\.\d+)%/, output) do
      [_, percentage] -> String.to_float(percentage)
      _ -> 0.0
    end
  end
  
  defp summarize_results(results) do
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("📋 COMPREHENSIVE TEST SUMMARY")
    IO.puts(String.duplicate("=", 50))
    
    passes = Enum.count(results, fn {_, status, _} -> status == :pass end)
    warnings = Enum.count(results, fn {_, status, _} -> status == :warn end)
    failures = Enum.count(results, fn {_, status, _} -> status == :fail end)
    
    Enum.each(results, fn {check, status, message} ->
      icon = case status do
        :pass -> "✅"
        :warn -> "⚠️ "
        :fail -> "❌"
      end
      
      IO.puts("#{icon} #{String.capitalize(to_string(check))}: #{message}")
    end)
    
    IO.puts("\n" <> String.duplicate("-", 50))
    IO.puts("📊 RESULTS: #{passes} passed, #{warnings} warnings, #{failures} failed")
    
    cond do
      failures > 0 ->
        IO.puts("🚨 CRITICAL ISSUES - Do not deploy!")
        System.halt(1)
      warnings > 0 ->
        IO.puts("⚠️  WARNINGS - Review before deploy")
        System.halt(0)
      true ->
        IO.puts("🎉 ALL CHECKS PASS - Ready to deploy!")
        System.halt(0)
    end
  end
end

# Run if called directly
if System.argv() == [] do
  ComprehensiveTest.run()
end