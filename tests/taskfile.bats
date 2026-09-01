#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	TASKFILE="${REPO_ROOT}/Taskfile.yml"
}

@test "bare task and task help show the project command guide" {
	run task --taskfile "${TASKFILE}"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"task list"* ]]
	[[ "${output}" == *"task create -- <product> <environment>"* ]]
	[[ "${output}" == *"product"*"Logical workspace or service name"* ]]
	[[ "${output}" == *"environment"*"Deployment environment"* ]]
	[[ "${output}" == *"CONFIG COMMANDS"* ]]
	[[ "${output}" == *"SETUP AND MAINTENANCE"* ]]
	[[ "${output}" == *"list"*"available configs and runtime state"* ]]
	default_output="${output}"

	run task --taskfile "${TASKFILE}" help
	[ "${status}" -eq 0 ]
	[ "${output}" = "${default_output}" ]
}

@test "Taskfile exposes the complete VM lifecycle with descriptions" {
	for command_name in create start stop logs delete status list stop-all validate path seed setup image:build image:status clean doctor check help; do
		grep -Eq "^  ${command_name}:" "${TASKFILE}"
	done
	grep -Fq 'task create -- demo dev' "${TASKFILE}"
	grep -Fq 'task start -- demo dev' "${TASKFILE}"
	grep -Fq 'task logs -- demo dev' "${TASKFILE}"
	grep -Fq 'task delete -- demo dev' "${TASKFILE}"
}

@test "Taskfile rejects missing and shell-like product arguments safely" {
	run task --taskfile "${TASKFILE}" path -- demo
	[ "${status}" -ne 0 ]
	[[ "${output}" == *"requires <product> <environment>"* ]]

	injected_path="${BATS_TEST_TMPDIR}/injected"
	run task --taskfile "${TASKFILE}" path -- "demo || touch ${injected_path} || true" dev
	[ "${status}" -ne 0 ]
	[ ! -e "${injected_path}" ]
}

@test "Nix shell supplies Task instead of a public vm package" {
	grep -Fq 'darwinPkgs.go-task' "${REPO_ROOT}/flake.nix"
	run grep -E 'writeShellApplication|apps\.\$\{darwinSystem\}|inherit tart vm' "${REPO_ROOT}/flake.nix"
	[ "${status}" -ne 0 ]
}

@test "README documents only the Task command surface" {
	grep -Fq 'task create -- demo dev' "${REPO_ROOT}/README.md"
	grep -Fq 'task validate -- demo dev' "${REPO_ROOT}/README.md"
	grep -Fq 'task setup' "${REPO_ROOT}/README.md"
	grep -Fq 'task help' "${REPO_ROOT}/README.md"
	run grep -E '^vm |`vm |vm --help' "${REPO_ROOT}/README.md"
	[ "${status}" -ne 0 ]
}
