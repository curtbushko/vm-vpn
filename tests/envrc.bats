#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test ".envrc loads the default flake development shell" {
	grep -Fxq 'use flake' "${REPO_ROOT}/.envrc"
}

@test "direnv state remains untracked" {
	grep -Fxq '.direnv' "${REPO_ROOT}/.gitignore"
}

@test "README documents automatic development-shell loading" {
	grep -Fq 'direnv allow' "${REPO_ROOT}/README.md"
}
