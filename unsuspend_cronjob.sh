#!/bin/bash
if [[ "$1" == "" ]]; then
  echo "unsuspend_cronjob.sh usage: unsuspend_cronjob.sh <namespace> [cronjob-name]"
  exit 1
fi
NAMESPACE=$1
if [[ "$2" != "" ]]; then
  CRONJOB=$2
  echo "kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p \"{\"spec\":{\"startingDeadlineSeconds\":null,\"suspend\":false}}\""
  kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p "{\"spec\":{\"startingDeadlineSeconds\":null,\"suspend\":false}}"
else
  CRONJOBS=`kubectl -n ${NAMESPACE} get cronjobs --no-headers=true -o custom-columns=NAME:.metadata.name`
  echo -e "\nThe following cronjobs will be unsuspended:\n\n${CRONJOBS}\n"
  read -n 2 -p "Proceed unsuspending cronjobs? [y/N]"
  if [[ "${REPLY}" != "y" ]]; then exit 1; fi
  for CRONJOB in ${CRONJOBS}; do
    echo "kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p \"{\"spec\":{\"startingDeadlineSeconds\":null,\"suspend\":false}}\""
    kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p "{\"spec\":{\"startingDeadlineSeconds\":null,\"suspend\":false}}"
  done
fi
