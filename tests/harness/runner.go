package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

// Options controls runner behavior.
type Options struct {
	PluginDir string
	WorkDir   string
	Keep      bool
	UnitOnly  bool
	Verbose   bool
	Timeout   time.Duration
}

// RunScenario executes a single test scenario and returns a report.
func RunScenario(scenario Scenario, opts Options) Report {
	var results []StepResult

	// Create or use work dir
	workDir := opts.WorkDir
	if workDir == "" {
		tmp, err := os.MkdirTemp("", "test-harness-*")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error creating temp dir: %v\n", err)
			return Report{ScenarioName: scenario.Name}
		}
		workDir = tmp
		if !opts.Keep {
			defer os.RemoveAll(workDir)
		}
	}

	if opts.Verbose {
		fmt.Printf("  Work dir: %s\n", workDir)
	}

	// Resolve plugin dir
	pluginDir := resolvePluginDir(scenario.PluginDir, opts.PluginDir)

	// Run setup commands
	for i, cmd := range scenario.Setup {
		expanded := expandWorkDir(cmd, workDir)
		if opts.Verbose {
			fmt.Printf("  [setup %d] %s\n", i+1, expanded)
		}
		out, code := runShell(workDir, expanded, pluginDir, opts.Timeout)
		if code != 0 {
			fmt.Fprintf(os.Stderr, "  Setup command %d failed (exit %d): %s\n%s\n", i+1, code, expanded, out)
			return Report{ScenarioName: scenario.Name, Results: results}
		}
	}

	// Execute steps
	session := &Session{WorkDir: workDir, PluginDir: pluginDir}

	for _, step := range scenario.Steps {
		if step.NewSession {
			session = &Session{WorkDir: workDir, PluginDir: pluginDir}
		}
		if len(step.AllowedTools) > 0 {
			session.Allowed = step.AllowedTools
		}

		var output string
		var exitCode int

		if step.Run != "" {
			// Shell command step
			expanded := expandWorkDir(step.Run, workDir)
			if opts.Verbose {
				fmt.Printf("  [run: %s] %s\n", step.Name, expanded)
			}
			output, exitCode = runShell(workDir, expanded, pluginDir, opts.Timeout)
			if opts.Verbose {
				fmt.Printf("  [exit: %d] %s\n", exitCode, truncate(output, 200))
			}
		} else if step.Prompt != "" {
			if opts.UnitOnly {
				if opts.Verbose {
					fmt.Printf("  [skip: %s] (unit-only mode)\n", step.Name)
				}
				continue
			}
			maxTurns := step.MaxTurns
			if maxTurns == 0 {
				maxTurns = 3
			}
			if opts.Verbose {
				fmt.Printf("  [prompt: %s] %s\n", step.Name, truncate(step.Prompt, 80))
			}
			result, err := session.Send(step.Prompt, maxTurns, opts.Verbose)
			if err != nil {
				fmt.Fprintf(os.Stderr, "  Claude error in step %q: %v\n", step.Name, err)
				output = err.Error()
			} else {
				output = result.Text
			}
		}

		// Run assertions
		for _, assertion := range step.Assertions {
			pass, detail := checkAssertion(workDir, assertion, output, exitCode)
			results = append(results, StepResult{
				StepName:  step.Name,
				Assertion: assertion,
				Pass:      pass,
				Detail:    detail,
			})
		}
	}

	// Run teardown commands
	for i, cmd := range scenario.Teardown {
		expanded := expandWorkDir(cmd, workDir)
		if opts.Verbose {
			fmt.Printf("  [teardown %d] %s\n", i+1, expanded)
		}
		runShell(workDir, expanded, pluginDir, opts.Timeout)
	}

	return Report{ScenarioName: scenario.Name, Results: results}
}

// runShell executes a shell command in the given directory and returns output + exit code.
func runShell(dir, command, pluginDir string, timeout time.Duration) (string, int) {
	if timeout == 0 {
		timeout = 2 * time.Minute
	}

	cmd := exec.Command("bash", "-c", command)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(),
		"WORK_DIR="+dir,
		"CLAUDE_PROJECT_DIR="+dir,
	)
	if pluginDir != "" {
		cmd.Env = append(cmd.Env, "PLUGIN_DIR="+pluginDir)
	}

	output, err := cmd.CombinedOutput()
	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			if status, ok := exitErr.Sys().(syscall.WaitStatus); ok {
				exitCode = status.ExitStatus()
			} else {
				exitCode = 1
			}
		} else {
			exitCode = 1
		}
	}

	return string(output), exitCode
}

// resolvePluginDir determines the plugin directory to use.
func resolvePluginDir(scenarioDir, flagDir string) string {
	if flagDir != "" {
		return flagDir
	}
	if scenarioDir != "" {
		return scenarioDir
	}
	// Auto-detect: walk up from cwd looking for .claude-plugin/marketplace.json
	cwd, _ := os.Getwd()
	dir := cwd
	for {
		if _, err := os.Stat(filepath.Join(dir, ".claude-plugin", "marketplace.json")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return ""
}

// expandWorkDir replaces $WORK_DIR in shell commands.
func expandWorkDir(cmd, workDir string) string {
	return strings.ReplaceAll(cmd, "$WORK_DIR", workDir)
}

// truncate shortens a string for display.
func truncate(s string, max int) string {
	s = strings.TrimSpace(s)
	if len(s) > max {
		return s[:max] + "..."
	}
	return s
}
