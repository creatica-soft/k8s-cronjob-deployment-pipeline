#!/bin/bash
TTL_SECONDS_AFTER_FINISHED=86400
if [[ "$1" == "" ]]; then
  echo "etTtlSecondsAfterFinished.sh usage: setTtlSecondsAfterFinished.sh <namespace> [cronjob-name]"
  exit 1
fi
NAMESPACE=$1
if [[ "$2" != "" ]]; then
  CRONJOB=$2
  echo "kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p \"{\"spec\":{\"jobTemplate\":{\"spec\":{\"ttlSecondsAfterFinished\":${TTL_SECONDS_AFTER_FINISHED}}}}}\""
  kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p "{\"spec\":{\"jobTemplate\":{\"spec\":{\"ttlSecondsAfterFinished\":${TTL_SECONDS_AFTER_FINISHED}}}}}"
else
  CRONJOBS=`kubectl -n ${NAMESPACE} get cronjobs --no-headers=true -o custom-columns=NAME:.metadata.name`
  echo -e "\nThe following cronjobs will be patched:\n\n${CRONJOBS}\n"
  read -n 2 -p "Proceed patching cronjobs? [y/N]"
  if [[ "${REPLY}" != "y" ]]; then exit 1; fi
  for CRONJOB in ${CRONJOBS}; do
    echo "kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p \"{\"spec\":{\"jobTemplate\":{\"spec\":{\"ttlSecondsAfterFinished\":${TTL_SECONDS_AFTER_FINISHED}}}}}\""
    kubectl -n ${NAMESPACE} patch cronjob ${CRONJOB} -p "{\"spec\":{\"jobTemplate\":{\"spec\":{\"ttlSecondsAfterFinished\":${TTL_SECONDS_AFTER_FINISHED}}}}}"
  done
fi
