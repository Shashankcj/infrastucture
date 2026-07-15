#!/bin/bash
set -e

echo "====================================="
echo "Event-driven ArgoCD Cluster Registration"
echo "====================================="

argocd login "${ARGOCD_SERVER}" \
    --username "${ARGOCD_USERNAME}" \
    --password "${ARGOCD_PASSWORD}" \
    --insecure

register_cluster() {
  local NAME=$1
  local NAMESPACE=$2
  local CLUSTER_NAME="${NAME%-kubeconfig}"

  echo "-------------------------------------"
  echo "New kubeconfig secret detected: ${NAME} (namespace: ${NAMESPACE})"
  echo "Waiting for cluster ${CLUSTER_NAME} to become Ready..."

  READY=""
  for i in $(seq 1 90); do
    READY=$(kubectl get cluster "${CLUSTER_NAME}" -n "${NAMESPACE}" \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")

    if [ "${READY}" == "True" ]; then
      echo "Cluster ${CLUSTER_NAME} is Ready."
      break
    fi

    echo "Not ready yet (attempt ${i}/90)... sleeping 10s"
    sleep 10
  done

  if [ "${READY}" != "True" ]; then
    echo "Timed out waiting for ${CLUSTER_NAME} to become Ready — skipping registration."
    return
  fi

  kubectl get secret "${NAME}" -n "${NAMESPACE}" -o jsonpath='{.data.value}' | base64 -d > /tmp/kubeconfig-${NAME}
  export KUBECONFIG=/tmp/kubeconfig-${NAME}

  CONTEXT=$(kubectl config current-context)
  SERVER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

  if argocd cluster list -o wide | grep -q "${SERVER_URL}"; then
    echo "Already registered — skipping."
  else
    echo "Registering..."
    argocd cluster add "${CONTEXT}" \
        --yes \
        --insecure \
        --label cluster-type=workload \
        --name "${CLUSTER_NAME}"
    echo "Registered ${CLUSTER_NAME} successfully!"
  fi

  unset KUBECONFIG
  rm -f /tmp/kubeconfig-${NAME}
}

echo "Watching for new kubeconfig secrets across all namespaces..."

while true; do
  kubectl get secrets -A --watch-only -o json 2>/dev/null | \
  jq --unbuffered -r '. | select(.metadata.name | endswith("-kubeconfig")) | "\(.metadata.name) \(.metadata.namespace)"' | \
  while read -r NAME NAMESPACE; do
    register_cluster "${NAME}" "${NAMESPACE}"
  done
  echo "Watch stream ended — reconnecting in 5s..."
  sleep 5
done