package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// checkAssertion evaluates a single assertion against the current state.
func checkAssertion(workDir string, a Assertion, output string, exitCode int) (bool, string) {
	var result bool
	var detail string

	switch a.Type {
	case "file_exists":
		path := filepath.Join(workDir, a.Path)
		_, err := os.Stat(path)
		result = err == nil
		if !result {
			detail = fmt.Sprintf("file %q does not exist", a.Path)
		}

	case "file_not_exists":
		path := filepath.Join(workDir, a.Path)
		_, err := os.Stat(path)
		result = os.IsNotExist(err)
		if !result {
			detail = fmt.Sprintf("file %q exists (expected not to)", a.Path)
		}

	case "file_contains":
		path := filepath.Join(workDir, a.Path)
		data, err := os.ReadFile(path)
		if err != nil {
			result = false
			detail = fmt.Sprintf("cannot read %q: %v", a.Path, err)
		} else {
			result = strings.Contains(string(data), a.Value)
			if !result {
				detail = fmt.Sprintf("file %q does not contain %q", a.Path, a.Value)
			}
		}

	case "file_not_contains":
		path := filepath.Join(workDir, a.Path)
		data, err := os.ReadFile(path)
		if err != nil {
			// File doesn't exist → content can't contain value → pass
			result = true
		} else {
			result = !strings.Contains(string(data), a.Value)
			if !result {
				detail = fmt.Sprintf("file %q contains %q (expected not to)", a.Path, a.Value)
			}
		}

	case "output_contains":
		result = strings.Contains(output, a.Value)
		if !result {
			// Show truncated output for debugging
			truncated := output
			if len(truncated) > 200 {
				truncated = truncated[:200] + "..."
			}
			detail = fmt.Sprintf("output does not contain %q (got: %s)", a.Value, truncated)
		}

	case "output_not_contains":
		result = !strings.Contains(output, a.Value)
		if !result {
			detail = fmt.Sprintf("output contains %q (expected not to)", a.Value)
		}

	case "exit_code":
		expected, err := strconv.Atoi(a.Value)
		if err != nil {
			result = false
			detail = fmt.Sprintf("invalid exit_code value %q", a.Value)
		} else {
			result = exitCode == expected
			if !result {
				detail = fmt.Sprintf("exit code %d != expected %d", exitCode, expected)
			}
		}

	case "json_field":
		path := filepath.Join(workDir, a.Path)
		data, err := os.ReadFile(path)
		if err != nil {
			result = false
			detail = fmt.Sprintf("cannot read %q: %v", a.Path, err)
		} else {
			result = checkJSONField(data, a.Value)
			if !result {
				detail = fmt.Sprintf("JSON field check failed for %q in %q", a.Value, a.Path)
			}
		}

	case "git_log_contains":
		out, code := runAssertionCmd(workDir, "git log --oneline 2>/dev/null")
		if code != 0 {
			result = false
			detail = "git log failed"
		} else {
			result = strings.Contains(out, a.Value)
			if !result {
				detail = fmt.Sprintf("git log does not contain %q", a.Value)
			}
		}

	case "git_status_clean":
		out, code := runAssertionCmd(workDir, "git status --porcelain 2>/dev/null")
		if code != 0 {
			result = false
			detail = "git status failed"
		} else {
			result = strings.TrimSpace(out) == ""
			if !result {
				detail = fmt.Sprintf("git working tree is not clean: %s", strings.TrimSpace(out))
			}
		}

	case "remote_has_ref":
		cmd := fmt.Sprintf("git -C %q show-ref --verify %s 2>/dev/null", a.Path, a.Value)
		_, code := runAssertionCmd(workDir, cmd)
		result = code == 0
		if !result {
			detail = fmt.Sprintf("remote %q does not have ref %q", a.Path, a.Value)
		}

	case "symlink_exists":
		path := filepath.Join(workDir, a.Path)
		fi, err := os.Lstat(path)
		if err != nil {
			result = false
			detail = fmt.Sprintf("path %q does not exist", a.Path)
		} else {
			result = fi.Mode()&os.ModeSymlink != 0
			if !result {
				detail = fmt.Sprintf("path %q exists but is not a symlink", a.Path)
			}
		}

	case "config_value":
		path := filepath.Join(workDir, a.Path)
		data, err := os.ReadFile(path)
		if err != nil {
			result = false
			detail = fmt.Sprintf("cannot read %q: %v", a.Path, err)
		} else {
			result = checkJSONField(data, a.Value)
			if !result {
				detail = fmt.Sprintf("config field check failed for %q in %q", a.Value, a.Path)
			}
		}

	default:
		result = false
		detail = fmt.Sprintf("unknown assertion type %q", a.Type)
	}

	if a.Negate {
		result = !result
		if detail != "" && result {
			detail = "" // negated + now passing = clear the error
		} else if !result {
			detail = fmt.Sprintf("negated assertion unexpectedly passed for type %q", a.Type)
		}
	}

	return result, detail
}

// runAssertionCmd runs a shell command for assertion checking.
func runAssertionCmd(workDir, command string) (string, int) {
	return runShell(workDir, command, "", nil, 30*time.Second)
}

// checkJSONField does a simple key existence check in JSON data.
// Value format: "key" checks existence, "key=value" checks equality.
func checkJSONField(data []byte, value string) bool {
	var obj map[string]interface{}
	if err := json.Unmarshal(data, &obj); err != nil {
		return false
	}

	parts := strings.SplitN(value, "=", 2)
	key := parts[0]

	val, exists := obj[key]
	if !exists {
		return false
	}

	if len(parts) == 2 {
		// Check value equality
		expected := parts[1]
		return fmt.Sprintf("%v", val) == expected
	}

	return true
}
