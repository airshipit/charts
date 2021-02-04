#!/bin/bash

#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
set -ex

# Default wait timeout is 1000 seconds
end=$(date +%s)
timeout=${3:-1000}
end=$((end + timeout))

while true; do
    pipelinerunstatus="$(kubectl get pipelinerun -n $1 $(kubectl get pipelinerun -n $1 -o name | awk -F '/' "/$2/ { print \$NF; exit }") | tail -1 | awk '{ print $2 }')"
    [ "${pipelinerunstatus}" == "True" ] && break
    [ "${pipelinerunstatus}" == "False" ] && exit 1
    sleep 5
    now=$(date +%s)
    if  [ $now -gt $end ] ; then
        echo "Pipelinerun failed to complete after $timeout seconds"
        echo
        kubectl get pipelinerun --namespace $1 -o wide
        echo "Some pipelineruns are not complete"
        exit 1
    fi
done
