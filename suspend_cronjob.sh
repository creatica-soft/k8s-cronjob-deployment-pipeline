#!/bin/bash
DEADLINE=300
if [[ "$1" == "" ]]; then
  echo "suspend_cronjob.sh usage: suspend_cronjob.sh <namespace> [cronjob-name]"
  exit 1
fi
NAMESPACE=$1
if [[ "$2" != "" ]]; then
  CRONJOB=$2
  echo "kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p \"{\"spec\":{\"startingDeadlineSeconds\":${DEADLINE},\"suspend\":true}}\""
  kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p "{\"spec\":{\"startingDeadlineSeconds\":${DEADLINE},\"suspend\":true}}"
else
  CRONJOBS=`kubectl -n ${NAMESPACE} get cronjobs --no-headers=true -o custom-columns=NAME:.metadata.name`
  echo -e "\nThe following cronjobs will be suspended:\n\n${CRONJOBS}\n"
  read -n 2 -p "Proceed suspending cronjobs? [y/N]"
  if [[ "${REPLY}" != "y" ]]; then exit 1; fi
  for CRONJOB in ${CRONJOBS}; do
    echo "kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p \"{\"spec\":{\"startingDeadlineSeconds\":${DEADLINE},\"suspend\":true}}\""
    kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p "{\"spec\":{\"startingDeadlineSeconds\":${DEADLINE},\"suspend\":true}}"
  done
fi
