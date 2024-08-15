#!/bin/bash

set -e

# Supported values for NUM_NS
VALID_NUM_NS=(1 25)

# Default values
NUM_NS=${NUM_NS:-"1"}
ROLLOUT_TIMEOUT=${ROLLOUT_TIMEOUT:-"5m"} # A time unit, e.g. 1s, 2m, 3h

# Check if NUM_NS is valid
if [[ ! " ${VALID_NUM_NS[*]} " =~ " $NUM_NS " ]]; then
  echo "Invalid value for NUM_NS. Supported values are 1 and 25."
  exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if kubectl is installed
if ! command_exists kubectl; then
    echo "kubectl is not installed. Please install kubectl before running this script."
    exit 1
fi

# Deploy the test app with error handling and rollback
kubectl apply -k manifests/app/$NUM_NS/base || {
    echo "Failed to apply Kubernetes resources: ${PIPESTATUS[0]}"
    kubectl delete -k manifests/app/$NUM_NS/base || {
        echo "Failed to delete Kubernetes resources: ${PIPESTATUS[0]}"
    }
    exit 1
}

# Function to handle rollout status and rollback
rollout_status_and_rollback() {
  local namespace=$1
  for deploy in tier-1-app-a tier-1-app-b tier-2-app-a tier-2-app-b tier-2-app-c tier-2-app-d tier-3-app-a tier-3-app-b; do
    kubectl rollout status deploy/$deploy -n $namespace --timeout=$ROLLOUT_TIMEOUT || {
      echo "Rollout status check failed for deployment $deploy in namespace $namespace: ${PIPESTATUS[0]}"
      kubectl delete -k manifests/app/$NUM_NS/base || {
        echo "Failed to delete Kubernetes resources: ${PIPESTATUS[0]}"
      }
      exit 1
    }
  done
}

# Wait for the tiered app rollout to complete
for i in $(seq 1 $NUM_NS); do
  rollout_status_and_rollback "ns-$i"
done

if [ "$NUM_NS" -eq 1 ]; then
  echo "Test app is running in $NUM_NS namespace."
else
  echo "Test app is running in $NUM_NS namespaces."
fi
