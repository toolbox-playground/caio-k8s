#!/usr/bin/env bash
# Remove o cluster do lab. (Em cluster real, delete a root app: os finalizers
# fazem cascade delete dos recursos gerenciados.)
set -euo pipefail
kind delete cluster --name gitops-prod
