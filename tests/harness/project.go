package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// TestProject holds paths for a provisioned test project.
type TestProject struct {
	BaseDir   string // temp root
	RemoteDir string // bare git remote
	WorkDir   string // cloned working copy
	PluginDir string // local marketplace with symlinked plugin
}

// ProjectConfig controls what gets provisioned.
type ProjectConfig struct {
	Git        bool              `yaml:"git"`
	Beads      bool              `yaml:"beads"`
	YfEnabled  bool              `yaml:"yf_enabled"`
	PluginLink bool              `yaml:"plugin_link"`
	Files      map[string]string `yaml:"files"`
}

// ProvisionProject creates a self-contained test environment:
// bare remote, cloned working copy, optional beads init, optional yf config.
func ProvisionProject(realPluginDir string, cfg ProjectConfig) (*TestProject, error) {
	baseDir, err := os.MkdirTemp("", "test-project-*")
	if err != nil {
		return nil, fmt.Errorf("mkdirTemp: %w", err)
	}

	project := &TestProject{BaseDir: baseDir}

	// Step 1: Create bare remote
	project.RemoteDir = filepath.Join(baseDir, "remote.git")
	if err := runGit(baseDir, "init", "--bare", project.RemoteDir); err != nil {
		return project, fmt.Errorf("git init --bare: %w", err)
	}

	// Step 2: Clone
	project.WorkDir = filepath.Join(baseDir, "project")
	if err := runGit(baseDir, "clone", project.RemoteDir, project.WorkDir); err != nil {
		return project, fmt.Errorf("git clone: %w", err)
	}

	// Step 3: Set git identity
	if err := runGit(project.WorkDir, "config", "user.email", "test@example.com"); err != nil {
		return project, err
	}
	if err := runGit(project.WorkDir, "config", "user.name", "Test User"); err != nil {
		return project, err
	}

	// Step 4: Create initial files and commit
	for relPath, content := range cfg.Files {
		absPath := filepath.Join(project.WorkDir, relPath)
		if err := os.MkdirAll(filepath.Dir(absPath), 0755); err != nil {
			return project, err
		}
		if err := os.WriteFile(absPath, []byte(content), 0644); err != nil {
			return project, err
		}
	}

	// Always create at least one file for initial commit
	readmePath := filepath.Join(project.WorkDir, "README.md")
	if _, err := os.Stat(readmePath); os.IsNotExist(err) {
		if err := os.WriteFile(readmePath, []byte("# Test Project\n"), 0644); err != nil {
			return project, err
		}
	}

	if err := runGit(project.WorkDir, "add", "-A"); err != nil {
		return project, err
	}
	if err := runGit(project.WorkDir, "commit", "-m", "initial commit"); err != nil {
		return project, err
	}
	if err := runGit(project.WorkDir, "push", "-u", "origin", "HEAD"); err != nil {
		return project, err
	}

	// Step 5: Create local marketplace with symlink
	if cfg.PluginLink && realPluginDir != "" {
		project.PluginDir = filepath.Join(baseDir, "local-plugins")
		marketplaceDir := filepath.Join(project.PluginDir, ".claude-plugin")
		if err := os.MkdirAll(marketplaceDir, 0755); err != nil {
			return project, err
		}

		catalog := map[string]interface{}{
			"name": "test-marketplace",
			"plugins": []map[string]string{
				{"name": "yf", "dir": "plugins/yf"},
			},
		}
		catalogJSON, _ := json.MarshalIndent(catalog, "", "  ")
		if err := os.WriteFile(filepath.Join(marketplaceDir, "marketplace.json"), catalogJSON, 0644); err != nil {
			return project, err
		}

		// Symlink plugins/yf -> real plugin source
		pluginsDir := filepath.Join(project.PluginDir, "plugins")
		if err := os.MkdirAll(pluginsDir, 0755); err != nil {
			return project, err
		}

		yfSource := filepath.Join(realPluginDir, "plugins", "yf")
		if err := os.Symlink(yfSource, filepath.Join(pluginsDir, "yf")); err != nil {
			return project, fmt.Errorf("symlink yf: %w", err)
		}
	}

	// Step 6: Run beads-setup if requested
	if cfg.Beads {
		setupScript := filepath.Join(realPluginDir, "plugins", "yf", "scripts", "beads-setup.sh")
		cmd := exec.Command("bash", setupScript)
		cmd.Dir = project.WorkDir
		cmd.Env = append(os.Environ(), "CLAUDE_PROJECT_DIR="+project.WorkDir)
		if out, err := cmd.CombinedOutput(); err != nil {
			return project, fmt.Errorf("beads-setup: %w\n%s", err, string(out))
		}
	}

	// Step 7: Enable yf if requested
	if cfg.YfEnabled {
		yfDir := filepath.Join(project.WorkDir, ".yoshiko-flow")
		if err := os.MkdirAll(yfDir, 0755); err != nil {
			return project, err
		}
		yfConfig := `{"enabled": true, "config": {"artifact_dir": "docs"}}`
		if err := os.WriteFile(filepath.Join(yfDir, "config.json"), []byte(yfConfig), 0644); err != nil {
			return project, err
		}

		// Run preflight
		if project.PluginDir != "" || realPluginDir != "" {
			preflightScript := filepath.Join(realPluginDir, "plugins", "yf", "scripts", "plugin-preflight.sh")
			cmd := exec.Command("bash", preflightScript)
			cmd.Dir = project.WorkDir
			cmd.Env = append(os.Environ(), "CLAUDE_PROJECT_DIR="+project.WorkDir)
			cmd.CombinedOutput() // best-effort
		}
	}

	return project, nil
}

// Cleanup removes all test project files.
func (p *TestProject) Cleanup() {
	if p != nil && p.BaseDir != "" {
		os.RemoveAll(p.BaseDir)
	}
}

// runGit runs a git command in the given directory.
func runGit(dir string, args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=Test User",
		"GIT_AUTHOR_EMAIL=test@example.com",
		"GIT_COMMITTER_NAME=Test User",
		"GIT_COMMITTER_EMAIL=test@example.com",
	)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("git %v: %w\n%s", args, err, string(out))
	}
	return nil
}
