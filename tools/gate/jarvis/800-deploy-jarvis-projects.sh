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
for jarvis_project in `find ./tools/gate/jarvis/5G-SA-core -maxdepth 1 -mindepth 1 -type d -printf '%f\n'`; do
  # Half of Jarvis-Projects will be made with required CI, half will be made with optional CI to
  # offer examples to developers using Jarvis.
  if (( COUNTER % 2 ));
  then
    voting_ci="true"
  else
    voting_ci="false"
  fi

  # shellcheck disable=SC2046
  helm upgrade \
      --create-namespace \
      --install \
      --namespace=jarvis-projects \
      "${jarvis_project}" \
      "./charts/jarvis-project" \
      --values="${gerrit_creds_override}" \
      --set config.ci.verify="$voting_ci" \
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
  #Copy CNF code, development-pipeline and standard-container into each CNF git repository
  cp -a tools/gate/jarvis/5G-SA-core/${jarvis_project}/. "${jarvis_sanity_repo}"
  cp -a tools/gate/jarvis/development-pipeline/* "${jarvis_sanity_repo}/jarvis/development-pipeline"
  cp -a tools/gate/jarvis/standard-container "${jarvis_sanity_repo}/jarvis"
  pushd "${jarvis_sanity_repo}"
  git review -s
  git add -A
  git commit -asm "Add project code and .gitreview file"
  git review
  change_id=`git log -1 | grep Change-Id: | awk '{print $2}'`
  popd
  sleep 180
  if (( COUNTER == 0 ));
  then
    CHANGE_ID_COUNTER=$change_id
  fi
  COUNTER=$((COUNTER+1))

done

for jarvis_project in `find ./tools/gate/jarvis/5G-SA-core -maxdepth 1 -mindepth 1 -type d -printf '%f\n'`; do
  # Check jarvis pipeline run
  end=$(date +%s)
  timeout="4000"
  end=$((end + timeout))
  while true; do
    result="$(curl -L https://gerrit.jarvis.local/changes/${CHANGE_ID_COUNTER}/revisions/1/checks | tail -1 | jq -r .[].state)"
    [ $result == "SUCCESSFUL" ] && break || true
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
  voting_ci="false"
  while true; do
    if [ $voting_ci = "true" ];
    then
      voting_ci="false"
      # Check that Jarvis-System has reported the success of the pipeline run to Gerrit, by checking the value of the Verified label
      VERIFIED="$(curl -L https://gerrit.jarvis.local/changes/${CHANGE_ID_COUNTER}/revisions/1/review/ | tail -1 | jq -r .labels.Verified.all[0].value)"
      [ "$VERIFIED" == 1 ] && break || true
      sleep 5
      now=$(date +%s)
      if [ "$now" -gt "$end" ] ; then
        echo "Jarvis-System has not verified the change"
        exit 1
      fi
    else
      voting_ci="true"
      # Ensure that the patchset doesn't have the Verified label available to it.
      LABELS=$(curl -L https://gerrit.jarvis.local/changes/${CHANGE_ID_COUNTER}/revisions/1/review/ | tail -1 | jq -r .labels)
      if [ -z "$LABELS" ]; then
        # The curl request didn't give us the labels available to this revision, try again when Gerrit is ready
        sleep 5
        continue
      fi
      VERIFIED_NULL="$( jq -r .Verified <<< "$LABELS" )"
      if [ -z "$VERIFIED_NULL" ]; then
        echo "Verified label found"
        # Verified label should not be found, exit.
        exit 1
      else
        # Labels curl returned all the labels successfully, and Verified was not in the list. This is desired.
        break
      fi
    fi
  done
  CHANGE_ID_COUNTER=$((CHANGE_ID_COUNTER+1))
done
