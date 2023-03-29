#!/usr/bin/bash

function delete_cronjob {
      kubectl -n ${NAMESPACE} delete cronjob ${JOBNAME}
      sleep 15s
      NEXUS_QUERY_STRING="${NEXUS_URL}/service/rest/v1/search?repository=${DOCKER_REPO}&name=repository/${DOCKER_REPO}/${DOCKER_IMAGE}&version=${VERSION}"
      COMPONENT_ID=`curl -u ${DOCKER_LOGIN}:$PASSWORD -X GET ${NEXUS_QUERY_STRING}|jq ".items[].id"|tr -d '"'`
      NEXUS_QUERY_STRING="${NEXUS_URL}/service/rest/v1/components/${COMPONENT_ID}"
      curl -sSi -u ${DOCKER_LOGIN}:$PASSWORD -X DELETE ${NEXUS_QUERY_STRING}
      ssh ${WORKER_NODE1} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION}
      ssh ${WORKER_NODE2} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION}
      ssh ${WORKER_NODE3} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION}
}

DOCKER_SERVER="nexus.example.com:8443"
DOCKER_REPO="docker-repo"
DOCKER_LOGIN="docker"
NEXUS_URL="https://nexus.example.com"
WORKER_NODE1="kube-minion-1"
WORKER_NODE2="kube-minion-2"
WORKER_NODE3="kube-minion-3"
MASTER_REPO="git-repo"
EMAIL_TO="support@example.com"
EMAIL_CC="logs@example.com"
PASSWORD=`kubectl get secrets docker -o json|jq ".data.password"|tr -d '"'|base64 -d`
export NEXUS_URL DOCKER_SERVER DOCKER_REPO DOCKER_LOGIN PASSWORD WORKER_NODE1 WORKER_NODE2 WORKER_NODE3

GITREPOS="repo1 repo2 repo3"
NAMESPACES="prod qa"
SCRIPTS="py r"

for GITREPO in ${GITREPOS}; do
  export GITREPO
  for NAMESPACE in ${NAMESPACES}; do
    export NAMESPACE
    for SCRIPT in ${SCRIPTS}; do
      export SCRIPT
      cd ~/bi-${GITREPO}-${NAMESPACE}-${SCRIPT}
      echo "bi-${GITREPO}-${NAMESPACE}-${SCRIPT}"
      git reset --hard -q
      sleep 1s
      git pull
      PROJECTS=`find . -maxdepth 2 -mindepth 2 -name project.ini|cut -f2 -d"/"`
      CRONJOBS=`kubectl -n ${NAMESPACE} get cronjobs.batch --no-headers -l team=${GITREPO},script=${SCRIPT}|awk '{print $1}'|cut -d"-" -f5-`
      for CRONJOB in ${CRONJOBS}; do
        JOBNAME="bi-${GITREPO}-${NAMESPACE}-${SCRIPT}-${CRONJOB}"
	export DOCKER_IMAGE="image-${JOBNAME}"
	export VERSION=`kubectl -n ${NAMESPACE} describe cronjob ${JOBNAME} | egrep "^\s+Image:\s+"|cut -f4 -d ":"`
	FOUND=false
        for PROJECT in ${PROJECTS}; do
          PROJECT=`echo ${PROJECT}|tr '[:upper:]' '[:lower:]'|tr '[:punct:]' '-'|tr '[:blank:]' '-'`
          if [[ "${CRONJOB}" == "${PROJECT}" ]]; then
            FOUND=true
            break
	  fi
        done
	if [[ "${FOUND}" == "false" ]]; then
          ORPHANS="${ORPHANS}\n${JOBNAME}"
          delete_cronjob
        fi
      done
      cd ..
    done
  done
done
if [[ "${ORPHANS}" != "" ]]; then
  echo -e "Hi, the following orphan cronjobs, i.e. with no project folder in git repo:\r\n\r\n${ORPHANS}\r\n\r\nhave been deleted\r\n" | mail -s "Deleted DS Orphan Cronjobs" ${EMAIL_CC} ${EMAIL_TO}
fi
unset NEXUS_URL DOCKER_SERVER DOCKER_REPO DOCKER_LOGIN PASSWORD WORKER_NODE1 WORKER_NODE2 WORKER_NODE3

