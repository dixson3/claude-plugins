package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

// Session manages a Claude CLI session with --resume chaining.
type Session struct {
	ID        string
	PluginDir string
	WorkDir   string
	Allowed   []string
}

// Result holds parsed JSON output from claude --output-format json.
type Result struct {
	SessionID string  `json:"session_id"`
	Text      string  `json:"result"`
	NumTurns  int     `json:"num_turns"`
	IsError   bool    `json:"is_error"`
	CostUSD   float64 `json:"total_cost_usd"`
}

// Send runs a prompt in the session, resuming if a session ID exists.
func (s *Session) Send(prompt string, maxTurns int, verbose bool) (*Result, error) {
	args := []string{"-p", prompt, "--output-format", "json"}

	if s.PluginDir != "" {
		args = append(args, "--plugin-dir", s.PluginDir)
	}
	if s.ID != "" {
		args = append(args, "--resume", s.ID)
	}
	if maxTurns > 0 {
		args = append(args, "--max-turns", strconv.Itoa(maxTurns))
	}
	if len(s.Allowed) > 0 {
		args = append(args, "--allowedTools", strings.Join(s.Allowed, ","))
	}

	cmd := exec.Command("claude", args...)
	cmd.Dir = s.WorkDir

	if verbose {
		fmt.Printf("    [claude] %s\n", strings.Join(args, " "))
	}

	output, err := cmd.CombinedOutput()
	if verbose {
		fmt.Printf("    [output] %s\n", string(output))
	}

	// Try to parse JSON result even if exit code is non-zero
	var result Result
	if jsonErr := json.Unmarshal(output, &result); jsonErr != nil {
		if err != nil {
			return nil, fmt.Errorf("claude command failed: %w\nOutput: %s", err, string(output))
		}
		// Non-JSON output but exit 0 — wrap as text
		result.Text = string(output)
	}

	// Preserve session ID for chaining
	if result.SessionID != "" {
		s.ID = result.SessionID
	}

	return &result, nil
}
