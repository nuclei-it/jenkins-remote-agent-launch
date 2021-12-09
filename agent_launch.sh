#!/usr/bin/env bash
# Launch Jenkins agent with system-wide SSH client
# Thus ssh_config can be applied to all Jenkins agent connections
# https://github.com/nuclei-it/jenkins-remote-agent-launch

set -Eeuo pipefail

# Configuration
# Agent JAR will be downloaded to this path on the remote node
AGENTJAR_PATH="./agent.jar"

# Note: https://stackoverflow.com/a/51805836/2646069
function ssh_helper() {
	ssh "$@" < /dev/null
	return $?
}

# Sanity checks
if [[ $EUID -eq 0 ]]; then
	>&2 echo "[-] This script must not run as root"
	exit 1
fi

# probe remote node availability
if ssh_helper "${NODE_NAME}" -- "uname"; then
	>&2 echo "[+] Connection to the remote node \"${NODE_NAME}\" succeeded."
else
	>&2 echo "[-] Unable to connect to the remote node \"${NODE_NAME}\". Check the hostname, networking, and SSH settings."
	exit 1
fi

# probe Java existence
if ! ssh_helper "${NODE_NAME}" -- "command -v java"; then
	>&2 echo "[-] Java is not available on the remote node. Please install JRE and put the JRE in the PATH."
	exit 127
fi

# download the agent
>&2 echo "[*] Provisioning agent..."
ssh_helper "${NODE_NAME}" -- "curl -L -o ${AGENTJAR_PATH} "${AGENTJAR_URL}""

# launch the agent
>&2 echo "[*] Launching agent..."
exec ssh "${NODE_NAME}" -- "java -jar "${AGENTJAR_PATH}""
