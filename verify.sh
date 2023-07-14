#!/usr/bin/env bash
#
# This file is part of the Kepler project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright 2023 The Kepler Contributors
#
set -eu -o pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
declare -r PROJECT_ROOT
# shellcheck source=lib/utils.sh
source "$PROJECT_ROOT/lib/utils.sh"

declare -r NAMESPACE=${NAMESPACE-"monitoring"}

rollout_status() {
	kubectl rollout status "$1" --namespace "$2" --timeout=5m ||
		die "failed to check status of ${1} inside namespace ${2}"
}

verify_bcc() {
	# basic check for bcc
	info "Verifying if bcc package is installed"
	dpkg -l | grep bcc 2>/dev/null ||
		rpm -qa | grep bcc 2>/dev/null ||
		die "no bcc binary found"

	ok "bcc package found"
}

verify_cluster() {
	# basic check for k8s cluster info
	info "Verifying cluster status"

	run kubectl cluster-info || die "failed to get the cluster-info"

	# check k8s system pod is there...
	[[ $(kubectl get pods --all-namespaces | wc -l) == 0 ]] &&
		die "it seems k8s cluster is not started"

	# check rollout status
	local resources
	resources=$(kubectl get deployments,statefulsets -n="$NAMESPACE" -o name)
	for res in $resources; do
		rollout_status "$res" "$NAMESPACE"
	done

	ok "Cluster is up and running"
}

main() {
	# verify the deployment of cluster
	case $1 in
	bcc)
		verify_bcc
		;;
	cluster)
		verify_cluster
		;;
	all | *)
		verify_bcc
		verify_cluster
		;;
	esac
}

main "${1:-all}"
