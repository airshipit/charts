#!/bin/bash
set -ex

for chart_path in `find ./tools/gate/jarvis/5G-SA-core -name Chart.yaml -exec dirname {} \;`; do
  helm lint ${chart_path}
  helm template ${chart_path} > /dev/null
done
