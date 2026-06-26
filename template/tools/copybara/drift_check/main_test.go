package main

import (
	"os"
	"path/filepath"
	"sort"
	"testing"
)

func makeSymlink(t *testing.T, dir, rel, target string) {
	t.Helper()
	full := filepath.Join(dir, rel)
	if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, full); err != nil {
		t.Fatal(err)
	}
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

func writeFile(t *testing.T, dir, rel, content string) {
	t.Helper()
	full := filepath.Join(dir, rel)
	if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(full, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func sortedDiffs(diffs []string) []string {
	out := make([]string, len(diffs))
	copy(out, diffs)
	sort.Strings(out)
	return out
}

// ---------------------------------------------------------------------------
// compareDirs unit tests
// ---------------------------------------------------------------------------

// TestCompareDirs_IdenticalTrees: two identical trees → no diffs.
func TestCompareDirs_IdenticalTrees(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	writeFile(t, a, "foo.go", "package main\n")
	writeFile(t, b, "foo.go", "package main\n")
	writeFile(t, a, "sub/bar.go", "package sub\n")
	writeFile(t, b, "sub/bar.go", "package sub\n")

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 0 {
		t.Errorf("expected no diffs, got: %v", diffs)
	}
}

// TestCompareDirs_ContentDifference: one file differs → reported.
func TestCompareDirs_ContentDifference(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	writeFile(t, a, "foo.go", "package main\n")
	writeFile(t, b, "foo.go", "package main // changed\n")

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 1 || diffs[0] != "foo.go" {
		t.Errorf("expected [foo.go], got: %v", diffs)
	}
}

// TestCompareDirs_FileOnlyInA: file in dirA but not dirB → reported.
func TestCompareDirs_FileOnlyInA(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	writeFile(t, a, "only_in_a.go", "content\n")

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 1 || diffs[0] != "only_in_a.go" {
		t.Errorf("expected [only_in_a.go], got: %v", diffs)
	}
}

// TestCompareDirs_FileOnlyInB: file in dirB but not dirA → reported.
func TestCompareDirs_FileOnlyInB(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	writeFile(t, b, "only_in_b.go", "content\n")

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 1 || diffs[0] != "only_in_b.go" {
		t.Errorf("expected [only_in_b.go], got: %v", diffs)
	}
}

// TestCompareDirs_ExcludedBasenamesIgnored: BUILD, BUILD.bazel, package-lock.json,
// sync-to-monorepo.yaml all differ but are excluded → no diffs.
func TestCompareDirs_ExcludedBasenamesIgnored(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	writeFile(t, a, "BUILD", "go_library()")
	writeFile(t, b, "BUILD", "different content")
	writeFile(t, a, "BUILD.bazel", "go_binary()")
	writeFile(t, b, "BUILD.bazel", "other content")
	writeFile(t, a, "package-lock.json", `{"lockfileVersion":2}`)
	writeFile(t, b, "package-lock.json", `{"lockfileVersion":3}`)
	writeFile(t, a, "sync-to-monorepo.yaml", "on: workflow_dispatch")
	writeFile(t, b, "sync-to-monorepo.yaml", "on: push")

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 0 {
		t.Errorf("expected no diffs (all excluded), got: %v", diffs)
	}
}

// TestCompareDirs_ExcludedNested: excluded basenames at nested paths are also ignored.
func TestCompareDirs_ExcludedNested(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	writeFile(t, a, "sub/pkg/BUILD", "go_library()")
	writeFile(t, b, "sub/pkg/BUILD", "different")
	// A non-excluded file that is identical.
	writeFile(t, a, "sub/pkg/foo.go", "package pkg\n")
	writeFile(t, b, "sub/pkg/foo.go", "package pkg\n")

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 0 {
		t.Errorf("expected no diffs (BUILD excluded), got: %v", diffs)
	}
}

// TestCompareDirs_MixedDiffs: multiple files differ and some are excluded.
func TestCompareDirs_MixedDiffs(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	writeFile(t, a, "main.go", "v1\n")
	writeFile(t, b, "main.go", "v2\n")
	writeFile(t, a, "sub/util.go", "util\n")
	writeFile(t, b, "sub/util.go", "util\n") // same — no diff
	writeFile(t, a, "BUILD", "mono BUILD")
	writeFile(t, b, "BUILD", "different BUILD") // excluded
	writeFile(t, a, "sub/extra.go", "extra\n")  // only in a

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	got := sortedDiffs(diffs)
	want := []string{"main.go", "sub/extra.go"}
	if len(got) != len(want) {
		t.Fatalf("expected diffs %v, got %v", want, got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("diff[%d]: got %q want %q", i, got[i], want[i])
		}
	}
}

// TestCompareDirs_EmptyDirsAreEqual: two empty directories → no diffs.
func TestCompareDirs_EmptyDirsAreEqual(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 0 {
		t.Errorf("expected no diffs, got: %v", diffs)
	}
}

// TestCompareDirs_DotGitExcluded: .git basename is excluded at any depth.
func TestCompareDirs_DotGitExcluded(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	writeFile(t, a, ".git/config", "[core]")
	writeFile(t, b, ".git/config", "different")

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 0 {
		t.Errorf("expected no diffs (.git excluded), got: %v", diffs)
	}
}

// ---------------------------------------------------------------------------
// compareDirs unit tests — symlink / presence cases
// ---------------------------------------------------------------------------

// TestCompareDirs_SymlinkIdentical: same symlink on both sides → no diff.
func TestCompareDirs_SymlinkIdentical(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	makeSymlink(t, a, "link.txt", "target.txt")
	makeSymlink(t, b, "link.txt", "target.txt")

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 0 {
		t.Errorf("expected no diffs (identical symlinks), got: %v", diffs)
	}
}

// TestCompareDirs_SymlinkTargetDiffers: symlink with differing target → diff.
func TestCompareDirs_SymlinkTargetDiffers(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	makeSymlink(t, a, "link.txt", "target_a.txt")
	makeSymlink(t, b, "link.txt", "target_b.txt")

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 1 || diffs[0] != "link.txt" {
		t.Errorf("expected [link.txt] (differing symlink targets), got: %v", diffs)
	}
}

// TestCompareDirs_SymlinkOnlyInA: symlink present only in dirA → diff.
func TestCompareDirs_SymlinkOnlyInA(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	makeSymlink(t, a, "link.txt", "target.txt")

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 1 || diffs[0] != "link.txt" {
		t.Errorf("expected [link.txt] (symlink only in A), got: %v", diffs)
	}
}

// TestCompareDirs_SymlinkOnlyInB: symlink present only in dirB → diff.
func TestCompareDirs_SymlinkOnlyInB(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	makeSymlink(t, b, "link.txt", "target.txt")

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 1 || diffs[0] != "link.txt" {
		t.Errorf("expected [link.txt] (symlink only in B), got: %v", diffs)
	}
}

// TestCompareDirs_FileVsSymlinkTypeMismatch: a path that is a regular file on
// one side and a symlink on the other → diff.
func TestCompareDirs_FileVsSymlinkTypeMismatch(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	writeFile(t, a, "entry", "content\n")
	makeSymlink(t, b, "entry", "target.txt")

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 1 || diffs[0] != "entry" {
		t.Errorf("expected [entry] (file vs symlink type mismatch), got: %v", diffs)
	}
}

// TestCompareDirs_EmptyDirOnlyInA: an empty directory present only in dirA → diff.
// (git doesn't track empty dirs so this is largely moot in practice, but
// compareDirs reports presence differences faithfully like `diff -r`.)
func TestCompareDirs_EmptyDirOnlyInA(t *testing.T) {
	a := t.TempDir()
	b := t.TempDir()
	if err := os.Mkdir(filepath.Join(a, "emptydir"), 0o755); err != nil {
		t.Fatal(err)
	}

	diffs, err := compareDirs(a, b, defaultExcluded())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(diffs) != 1 || diffs[0] != "emptydir" {
		t.Errorf("expected [emptydir] (empty dir only in A), got: %v", diffs)
	}
}
