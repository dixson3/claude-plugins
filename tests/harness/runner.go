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
	PluginDir       string
	WorkDir         string
	Keep            bool
	UnitOnly        bool
	IntegrationOnly bool
	Verbose         bool
	Timeout         time.Duration
}

// RunScenario executes a single test scenario and returns a report.
func RunScenario(scenario Scenario, opts Options) Report {
	var results []StepResult

	// Skip integration tests in unit-only mode
	if opts.UnitOnly && scenario.Type == "integration" {
		if opts.Verbose {
			fmt.Printf("  [skip] integration scenario in unit-only mode\n")
		}
		return Report{ScenarioName: scenario.Name}
	}

	// Skip unit tests in integration-only mode
	if opts.IntegrationOnly && scenario.Type != "integration" {
		if opts.Verbose {
			fmt.Printf("  [skip] unit scenario in integration-only mode\n")
		}
		return Report{ScenarioName: scenario.Name}
	}

	// Resolve plugin dir early (needed for project provisioning)
	pluginDir := resolvePluginDir(scenario.PluginDir, opts.PluginDir)

	// Provision test project if configured
	var project *TestProject
	var remoteDir string
	var localPluginDir string

	if scenario.Project != nil && scenario.Project.Git {
		var err error
		project, err = ProvisionProject(pluginDir, *scenario.Project)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error provisioning project: %v\n", err)
			if project != nil && !opts.Keep {
				project.Cleanup()
			}
			return Report{ScenarioName: scenario.Name}
		}
		if !opts.Keep {
			defer project.Cleanup()
		}
	}

	// Create or use work dir
	workDir := opts.WorkDir
	if project != nil {
		workDir = project.WorkDir
		remoteDir = project.RemoteDir
		if project.PluginDir != "" {
			localPluginDir = project.PluginDir
		}
	} else if workDir == "" {
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
		if remoteDir != "" {
			fmt.Printf("  Remote dir: %s\n", remoteDir)
		}
	}

	// Build extra environment for project-aware steps
	extraEnv := map[string]string{}
	if remoteDir != "" {
		extraEnv["REMOTE_DIR"] = remoteDir
	}
	if localPluginDir != "" {
		extraEnv["LOCAL_PLUGIN_DIR"] = localPluginDir
	}

	// Determine effective plugin dir for sessions
	sessionPluginDir := pluginDir
	if localPluginDir != "" {
		sessionPluginDir = localPluginDir
	}

	// Run setup commands
	for i, cmd := range scenario.Setup {
		expanded := expandVars(cmd, workDir, remoteDir)
		if opts.Verbose {
			fmt.Printf("  [setup %d] %s\n", i+1, expanded)
		}
		out, code := runShell(workDir, expanded, pluginDir, extraEnv, opts.Timeout)
		if code != 0 {
			fmt.Fprintf(os.Stderr, "  Setup command %d failed (exit %d): %s\n%s\n", i+1, code, expanded, out)
			return Report{ScenarioName: scenario.Name, Results: results}
		}
	}

	// Execute steps
	session := &Session{WorkDir: workDir, PluginDir: sessionPluginDir}

	for _, step := range scenario.Steps {
		if step.NewSession {
			session = &Session{WorkDir: workDir, PluginDir: sessionPluginDir}
		}
		if len(step.AllowedTools) > 0 {
			session.Allowed = step.AllowedTools
		}

		var output string
		var exitCode int

		if step.Run != "" {
			// Shell command step
			expanded := expandVars(step.Run, workDir, remoteDir)
			if opts.Verbose {
				fmt.Printf("  [run: %s] %s\n", step.Name, expanded)
			}
			output, exitCode = runShell(workDir, expanded, pluginDir, extraEnv, opts.Timeout)
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
		expanded := expandVars(cmd, workDir, remoteDir)
		if opts.Verbose {
			fmt.Printf("  [teardown %d] %s\n", i+1, expanded)
		}
		runShell(workDir, expanded, pluginDir, extraEnv, opts.Timeout)
	}

	return Report{ScenarioName: scenario.Name, Results: results}
}

// runShell executes a shell command in the given directory and returns output + exit code.
func runShell(dir, command, pluginDir string, extraEnv map[string]string, timeout time.Duration) (string, int) {
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
	for k, v := range extraEnv {
		cmd.Env = append(cmd.Env, k+"="+v)
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

// expandVars replaces $WORK_DIR and $REMOTE_DIR in shell commands.
func expandVars(cmd, workDir, remoteDir string) string {
	result := strings.ReplaceAll(cmd, "$WORK_DIR", workDir)
	if remoteDir != "" {
		result = strings.ReplaceAll(result, "$REMOTE_DIR", remoteDir)
	}
	return result
}

// truncate shortens a string for display.
func truncate(s string, max int) string {
	s = strings.TrimSpace(s)
	if len(s) > max {
		return s[:max] + "..."
	}
	return s
}
