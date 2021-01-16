#!/bin/bash
set -ex

gerrit_source=$(mktemp -d)
repo_sha="251041b192ef8acf1963d747482126d0e9e66e75"
repo_remote="https://gerrit.googlesource.com/k8s-gerrit"

function get_repo() {
    pushd "${1}"
    git init
    git remote add origin "${2}"
    git fetch origin --depth=1 "${3}"
    git reset --hard FETCH_HEAD
    popd
}
get_repo "${gerrit_source}" "${repo_remote}" "${repo_sha}"

# TODO: This needs fixed upstream
patch ${gerrit_source}/helm-charts/gerrit/templates/gerrit.stateful-set.yaml <<'EOF'
--- /tmp/tmp.8ZADMTe64b/helm-charts/gerrit/templates/gerrit.stateful-set.yaml   2021-01-16 21:33:32.331105033 +0000
+++ /tmp/tmp.z8R6CX0Gqg/helm-charts/gerrit/templates/gerrit.stateful-set.yaml   2021-01-16 20:11:36.275929405 +0000
@@ -57,9 +57,14 @@
         imagePullPolicy: {{ .Values.images.imagePullPolicy }}
         command:
         - /bin/ash
-        - -ce
+        - -cex
         args:
         - |
+          python3 /var/tools/gerrit-initializer \
+            -c /var/config/gerrit-init.yaml \
+            -s /var/gerrit \
+            init
+
           symlink_config_to_site(){
             for file in /var/mnt/etc/config/* /var/mnt/etc/secret/*; do
               ln -sf $file /var/gerrit/etc/$(basename $file)
EOF

function generate_ssh_host_key_override() {
  local work_dir
  work_dir="$(mktemp -d)"
  mkdir -p "${work_dir}/etc/ssh"
  ssh-keygen -A -f "${work_dir}"
  local output_file
  output_file="$(mktemp -d)/gerrit-host-rsa-key.yaml"
  tee "${output_file}" <<EOF
gerrit:
  service:
    ssh:
      rsaKey: |-
$(awk  '{ print "        " $0 }' "${work_dir}/etc/ssh/ssh_host_rsa_key")
EOF
  export ssh_host_key_override="${output_file}"
}
generate_ssh_host_key_override

# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=gerrit \
    gerrit \
    "${gerrit_source}/helm-charts/gerrit" \
    --values="${ssh_host_key_override}" \
    $(./tools/deployment/common/get-values-overrides.sh gerrit)

./tools/deployment/common/wait-for-pods.sh gerrit

#TODO(portdirect): Update chart to support SSH via TCP ingress, in addition to being able to spec nodeport
kubectl patch -n gerrit svc gerrit-gerrit-service --patch '{
  "spec": {
    "ports": [
      {
        "name": "ssh",
        "nodePort": 29418,
        "port": 29418,
        "protocol": "TCP",
        "targetPort": 29418
      }
    ]
  }
}'
sleep 30

function gerrit_bootstrap() {
  # Define creds to use for gerrit.
  ldap_username="jarvis"
  ldap_password="password"

  # Login to gerrit, to provision admin account
  curl --verbose \
    -d "username=${ldap_username}&password=${ldap_password}" \
    -X POST \
    https://gerrit.jarvis.local/login

  # Create SSH Keys if the private key does not already exist, note this will fail if a public key already
  # exists at the default location without a corresponding private key.
  mkdir -p "${HOME}/.ssh"
  if [[ ! -f "${HOME}/.ssh/id_rsa" ]]; then
    ssh-keygen -t rsa -f "${HOME}/.ssh/id_rsa" -q -N ""
  fi

  # Add SSH Public key to gerrit
  curl --verbose \
    -u "${ldap_username}:${ldap_password}" \
    -X POST \
    -H "Content-Type: text/plain" \
    --data "@${HOME}/.ssh/id_rsa.pub" \
    https://gerrit.jarvis.local/a/accounts/self/sshkeys/

  # Add Gerrit HostKey to SSH known hosts
  ssh-keyscan -p 29418 -H gerrit.jarvis.local >> "${HOME}/.ssh/known_hosts"

  # Validate access to gerrit via SSH
  ssh -p 29418 ${ldap_username}@gerrit.jarvis.local gerrit version

  # Configure Git
  git config --global user.name "Edwin Jarvis"
  git config --global user.email "jarvis@cluster.local"
  git config --global --add gitreview.username "jarvis"

  # Clone, fetch and checkout project config repo
  all_projects_repo=$(mktemp -d)
  git clone ssh://${ldap_username}@gerrit.jarvis.local:29418/All-Projects.git "${all_projects_repo}"
  pushd "${all_projects_repo}"
  git fetch origin refs/meta/config:refs/remotes/origin/meta/config
  git checkout meta/config

  # Configure Verified Label
  tee --append project.config <<EOF
[label "Verified"]
        function = MaxWithBlock
        defaultValue = 0
        value = -1 Fails
        value = 0 No score
        value = +1 Verified
        copyAllScoresIfNoCodeChange = true
EOF

  # Give Admins, Service Users and Project Owners voting rights for the Verified Label
  sed -i '/\[access "refs\/heads\/\*"\]/a\ \ \ \ \ \ \ \ label-Verified = -1..+1 group Administrators\n\ \ \ \ \ \ \ \ label-Verified = -1..+1 group Service Users\n\ \ \ \ \ \ \ \ label-Verified = -1..+1 group Project Owners' project.config

  # Give Admins, Service Users and Project Owners voting rights for the Verified Label
  sed -i '/\[capability\]/a\ \ \ \ \ \ \ \ checks-administrateCheckers = group Administrators' project.config

  # Commit and push config
  git add .
  git commit -asm "Create Verified Label"
  git push origin HEAD:refs/meta/config
  popd
}

gerrit_bootstrap
