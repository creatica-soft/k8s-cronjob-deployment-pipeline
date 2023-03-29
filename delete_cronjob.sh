#!/bin/bash
if [[ "$1" == "" ]]; then 
  echo "delete_cronjob.sh usage: delete_cronjob.sh <full-job-name> [docker-image-version]"
  exit 1
fi

DOCKER_SERVER="nexus.example.com:8443"
DOCKER_REPO="docker-repo"
DOCKER_LOGIN="docker"
NEXUS_URL="https://nexus.example.com"
WORKER_NODE1="kube-minion-1"
WORKER_NODE2="kube-minion-2"
WORKER_NODE3="kube-minion-3"
MASTER_REPO="git-repo"
PASSWORD=`kubectl get secrets docker -o json|jq ".data.password"|tr -d '"'|base64 -d`

NAMESPACE=`echo $1|cut -f3 -d "-"`
JOBNAME=$1
DOCKER_IMAGE="image-${JOBNAME}"
if [[ "$2" != "" ]]; then
  VERSION=$2
else 
  VERSION=`kubectl -n ${NAMESPACE} describe cronjob ${JOBNAME} | egrep "^\s+Image:\s+"|cut -f4 -d ":"`
fi

echo "NAMESPACE=${NAMESPACE}"
echo "JOBNAME=${JOBNAME}"
echo "DOCKER_IMAGE=${DOCKER_IMAGE}"
echo "VERSION=${VERSION}"

read -n 2 -p "Proceed deleting cronjob? [y/N]"

if [[ "${REPLY}" != "y" ]]; then exit 1; fi

echo -e "kubectl -n ${NAMESPACE} delete cronjob ${JOBNAME}\r"
kubectl -n ${NAMESPACE} delete cronjob ${JOBNAME}
sleep 30s
NEXUS_QUERY_STRING="${NEXUS_URL}/service/rest/v1/search?repository=${DOCKER_REPO}&name=repository/${DOCKER_REPO}/${DOCKER_IMAGE}&version=${VERSION}"
echo -e "COMPONENT_ID=\`curl -u qas-datascience-lat -X GET ${NEXUS_QUERY_STRING}|jq \".items[].id\"|tr -d \"\`\r"
COMPONENT_ID=`curl -u ${DOCKER_LOGIN}:$PASSWORD -X GET ${NEXUS_QUERY_STRING}|jq ".items[].id"|tr -d '"'`
NEXUS_QUERY_STRING="${NEXUS_URL}/service/rest/v1/components/${COMPONENT_ID}"
echo -e "curl -sSi -u ${DOCKER_LOGIN} -X DELETE ${NEXUS_QUERY_STRING}\r"
curl -sSi -u ${DOCKER_LOGIN}:$PASSWORD -X DELETE ${NEXUS_QUERY_STRING}
echo -e "ssh ${WORKER_NODE1} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION}\r"
ssh ${WORKER_NODE1} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION}
echo -e "ssh ${WORKER_NODE2} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION}\r"
ssh ${WORKER_NODE2} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION}
echo -e "ssh ${WORKER_NODE3} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION}\r"
ssh ${WORKER_NODE3} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION}

