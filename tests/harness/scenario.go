package main

// Scenario represents a YAML test scenario file.
type Scenario struct {
	Name      string   `yaml:"name"`
	PluginDir string   `yaml:"plugin_dir"`
	Remote    string   `yaml:"remote"`
	Setup     []string `yaml:"setup"`
	Teardown  []string `yaml:"teardown"`
	Steps     []Step   `yaml:"steps"`
}

// Step is a single test step — either a Claude prompt or a shell command.
type Step struct {
	Name         string      `yaml:"name"`
	Prompt       string      `yaml:"prompt"`
	Run          string      `yaml:"run"`
	MaxTurns     int         `yaml:"max_turns"`
	AllowedTools []string    `yaml:"allowed_tools"`
	NewSession   bool        `yaml:"new_session"`
	Assertions   []Assertion `yaml:"assertions"`
}

// Assertion defines a single check after a step completes.
type Assertion struct {
	Type   string `yaml:"type"`
	Path   string `yaml:"path"`
	Value  string `yaml:"value"`
	Negate bool   `yaml:"negate"`
}

// StepResult records the pass/fail outcome of a single assertion within a step.
type StepResult struct {
	StepName  string
	Assertion Assertion
	Pass      bool
	Detail    string
}

// Report aggregates all results for a scenario.
type Report struct {
	ScenarioName string
	Results      []StepResult
}
