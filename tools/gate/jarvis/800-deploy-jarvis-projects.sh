#!/bin/bash
set -ex

function generate_gerrit_creds_override() {
  local output_file
  output_file="$(mktemp -d)/gerrit-host-rsa-key.yaml"
  tee "${output_file}" <<EOF
params:
  gerrit:
    user: jarvis
    password: password
    ssh_key: |
$(awk  '{ print "      " $0 }' "${HOME}/.ssh/id_rsa")
EOF
  export gerrit_creds_override="${output_file}"
}
generate_gerrit_creds_override

COUNTER=0
for jarvis_project in $(find ./tools/gate/jarvis/5G-SA-core -maxdepth 1 -mindepth 1 -type d -printf '%f\n'); do
  # Half of Jarvis-Projects will be made with required CI, half will be made with optional CI to
  # offer examples to developers using Jarvis.
  if (( COUNTER % 2 ));
  then
    voting_ci="true"
  else
    voting_ci="false"
  fi

  project_override=$(mktemp --suffix=.yaml)
  tee ${project_override} <<EOF
config:
  ci:
    verify: ${voting_ci}
params:
  harbor:
    member_ldap_dn:
      project: cn=${jarvis_project}-harbor-users-group,ou=Groups,dc=jarvis,dc=local
      staging: cn=${jarvis_project}-harbor-staging-users-group,ou=Groups,dc=jarvis,dc=local
  gerrit:
    ldap_group_cn: ${jarvis_project}-dev-users-group
EOF

  # shellcheck disable=SC2046
  helm upgrade \
    --create-namespace \
    --install \
    --namespace=jarvis-projects \
    "${jarvis_project}" \
    "./charts/jarvis-project" \
    --values="${gerrit_creds_override}" \
    --values="${project_override}" \
    $(./tools/deployment/common/get-values-overrides.sh jarvis-project)

  ./tools/deployment/common/wait-for-pods.sh jarvis-projects

  sleep 60

  # Define creds to use for gerrit.
  ldap_username="jarvis"

  # Commit .gitreview and project code
  jarvis_sanity_repo=$(mktemp -d)
  git clone ssh://${ldap_username}@gerrit.jarvis.local:29418/${jarvis_project}.git "${jarvis_sanity_repo}"
  pushd "${jarvis_sanity_repo}"
  popd
  # Add kubeconfig and ca to jarvis.yaml as single line base64 encoded so that to preserve the indentation required to be a valid kubeconfig
  KUBECONFIG=$(base64 -w 0 ~/.kube/config)
  CRT=$(base64 -w0 /etc/jarvis/certs/ca/ca.pem)
  echo "$KUBECONFIG" | xargs -n 1 -I {} yq eval -i '.dev."jarvis-aio".kubeconfig = "{}"' tools/gate/jarvis/5G-SA-core/${jarvis_project}/jarvis.yaml
  echo "$CRT" | xargs -n 1 -I {} yq eval -i '.dev."jarvis-aio"."harbor-ca" = "{}"' tools/gate/jarvis/5G-SA-core/${jarvis_project}/jarvis.yaml
  #Copy CNF code, development-pipeline and standard-container into each CNF git repository
  cp -a tools/gate/jarvis/5G-SA-core/${jarvis_project}/. "${jarvis_sanity_repo}"
  cp -a tools/gate/jarvis/development-pipeline/* "${jarvis_sanity_repo}/jarvis/development-pipeline"
  cp -a tools/gate/jarvis/standard-container "${jarvis_sanity_repo}/jarvis"
  pushd "${jarvis_sanity_repo}"
  git review -s
  git add -A
  git commit -asm "Add project code and .gitreview file"
  git review
  change_id=$(git log -1 | grep Change-Id: | awk '{print $2}')
  popd
  sleep 60
  COUNTER=$((COUNTER+1))
done

COUNTER=1
voting_ci="false"
for jarvis_project in $(find ./tools/gate/jarvis/5G-SA-core -maxdepth 1 -mindepth 1 -type d -printf '%f\n'); do
  echo "--- processing ${jarvis_project} with voting_ci = ${voting_ci}"
  # Check jarvis pipeline run
  end=$(date +%s)
  timeout="4000"
  end=$((end + timeout))
  while true; do
    result="$(curl -u jarvis:password -SsL https://gerrit.jarvis.local/a/changes/${COUNTER}/revisions/1/checks | tail -1 | jq -r .[].state)"
    [ $result == "SUCCESSFUL" ] && break || true
    [ $result == "FAILED" ] && exit 1 || true
    sleep 25
    now=$(date +%s)
    if [ $now -gt $end ] ; then
      echo "Pipeline failed to complete $timeout seconds"
      exit 1
    fi
  done

  # Check that Jarvis-System has reported the success of the pipeline run to Gerrit
  end=$(date +%s)
  timeout="120"
  end=$((end + timeout))
  while true; do
    # Check that Jarvis-System has reported the success of the pipeline run to Gerrit, by checking the value of the Verified label
    VERIFIED="$(curl -u jarvis:password -SsL https://gerrit.jarvis.local/a/changes/${COUNTER}/revisions/1/review/ | tail -1 | jq -r .labels.Verified.all[0].value)"
    if [ "$VERIFIED" == 1 ] ; then
      if [ "${jarvis_project}" == "mongodb" ] ; then
        echo "Merging mongodb patchset"
        ssh -p 29418 jarvis@gerrit.jarvis.local gerrit review "${COUNTER}",1 --label Workflow=1 --label Code-Review=2
        sleep 60
        #Setting a longer timeout if it is going through the Merge pipeline.
        timeout="720"
        end=$((end + timeout))
        while true; do
          MERGED="$(curl -u jarvis:password -SsL https://gerrit.jarvis.local/a/changes/${COUNTER}/revisions/1/review/ | tail -1 | jq -r .status)"
          kubectl get pods -n "jarvis-${COUNTER}-1"
          if [ "$MERGED" == "MERGED" ] ; then
             break
          else
             sleep 20
             true
          fi
          now=$(date +%s)
          if [ "$now" -gt "$end" ] ; then
             echo "Jarvis-System has not merged the change"
             exit 1
          fi
        done
        break
      else
        break
      fi
    else
      true
    fi
    sleep 5
    now=$(date +%s)
    if [ "$now" -gt "$end" ] ; then
      echo "Jarvis-System has not verified the change"
      exit 1
    fi
  done
  COUNTER=$((COUNTER+1))
done
