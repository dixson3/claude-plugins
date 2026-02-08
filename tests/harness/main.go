package main

import (
	"flag"
	"fmt"
	"os"
	"time"

	"gopkg.in/yaml.v3"
)

func main() {
	pluginDir := flag.String("plugin-dir", "", "Path to marketplace plugin directory (default: auto-detect)")
	workDir := flag.String("work-dir", "", "Working directory (default: temp dir per scenario)")
	keep := flag.Bool("keep", false, "Don't clean up work dir after tests")
	unitOnly := flag.Bool("unit-only", false, "Skip steps that call claude (run only 'run' steps)")
	verbose := flag.Bool("verbose", false, "Show full command/claude output")
	timeout := flag.Duration("timeout", 2*time.Minute, "Per-step timeout")

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: test-harness [flags] <scenario.yaml> [scenario2.yaml ...]\n\nFlags:\n")
		flag.PrintDefaults()
	}
	flag.Parse()

	args := flag.Args()
	if len(args) == 0 {
		flag.Usage()
		os.Exit(1)
	}

	opts := Options{
		PluginDir: *pluginDir,
		WorkDir:   *workDir,
		Keep:      *keep,
		UnitOnly:  *unitOnly,
		Verbose:   *verbose,
		Timeout:   *timeout,
	}

	totalPass := 0
	totalFail := 0
	var failedScenarios []string

	for _, path := range args {
		scenario, err := loadScenario(path)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error loading %s: %v\n", path, err)
			os.Exit(1)
		}

		fmt.Printf("\n--- %s ---\n", scenario.Name)
		report := RunScenario(scenario, opts)

		pass, fail := 0, 0
		for _, r := range report.Results {
			if r.Pass {
				pass++
				fmt.Printf("  PASS  %s: %s\n", r.StepName, assertionSummary(r.Assertion))
			} else {
				fail++
				fmt.Printf("  FAIL  %s: %s\n", r.StepName, assertionSummary(r.Assertion))
				if r.Detail != "" {
					fmt.Printf("        %s\n", r.Detail)
				}
			}
		}

		fmt.Printf("  Result: %d passed, %d failed\n", pass, fail)
		totalPass += pass
		totalFail += fail
		if fail > 0 {
			failedScenarios = append(failedScenarios, scenario.Name)
		}
	}

	fmt.Printf("\n=== Summary: %d passed, %d failed ===\n", totalPass, totalFail)
	if len(failedScenarios) > 0 {
		fmt.Printf("Failed scenarios:\n")
		for _, name := range failedScenarios {
			fmt.Printf("  - %s\n", name)
		}
		os.Exit(1)
	}
}

func loadScenario(path string) (Scenario, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Scenario{}, err
	}

	var scenario Scenario
	if err := yaml.Unmarshal(data, &scenario); err != nil {
		return Scenario{}, fmt.Errorf("parsing %s: %w", path, err)
	}

	if scenario.Name == "" {
		scenario.Name = path
	}

	return scenario, nil
}

func assertionSummary(a Assertion) string {
	neg := ""
	if a.Negate {
		neg = " (negated)"
	}
	switch a.Type {
	case "file_exists":
		return fmt.Sprintf("file_exists(%s)%s", a.Path, neg)
	case "file_not_exists":
		return fmt.Sprintf("file_not_exists(%s)%s", a.Path, neg)
	case "file_contains":
		return fmt.Sprintf("file_contains(%s, %q)%s", a.Path, a.Value, neg)
	case "file_not_contains":
		return fmt.Sprintf("file_not_contains(%s, %q)%s", a.Path, a.Value, neg)
	case "output_contains":
		return fmt.Sprintf("output_contains(%q)%s", a.Value, neg)
	case "output_not_contains":
		return fmt.Sprintf("output_not_contains(%q)%s", a.Value, neg)
	case "exit_code":
		return fmt.Sprintf("exit_code(%s)%s", a.Value, neg)
	case "json_field":
		return fmt.Sprintf("json_field(%s, %q)%s", a.Path, a.Value, neg)
	default:
		return fmt.Sprintf("%s(%s, %q)%s", a.Type, a.Path, a.Value, neg)
	}
}
