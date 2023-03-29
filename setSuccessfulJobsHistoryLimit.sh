#!/bin/bash
JOB_NUMBER=0
if [[ "$1" == "" ]]; then
  echo "setSuccessfulJobsHistoryLimit.sh usage: setSuccessfulJobsHistoryLimit.sh <namespace> [cronjob-name]"
  exit 1
fi
NAMESPACE=$1
if [[ "$2" != "" ]]; then
  CRONJOB=$2
  echo "kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p \"{\"spec\":{\"successfulJobsHistoryLimit\":${JOB_NUMBER}}}\""
  kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p "{\"spec\":{\"successfulJobsHistoryLimit\":${JOB_NUMBER}}}"
else
  CRONJOBS=`kubectl -n ${NAMESPACE} get cronjobs --no-headers=true -o custom-columns=NAME:.metadata.name`
  echo -e "\nThe following cronjobs will be patched:\n\n${CRONJOBS}\n"
  read -n 2 -p "Proceed patching cronjobs? [y/N]"
  if [[ "${REPLY}" != "y" ]]; then exit 1; fi
  for CRONJOB in ${CRONJOBS}; do
    echo "kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p \"{\"spec\":{\"successfulJobsHistoryLimit\":${JOB_NUMBER}}}\""
    kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p "{\"spec\":{\"successfulJobsHistoryLimit\":${JOB_NUMBER}}}"
  done
fi
