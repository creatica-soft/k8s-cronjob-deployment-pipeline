#!/bin/bash
TTL_SECONDS_AFTER_FINISHED=86400
if [[ "$1" == "" ]]; then
  echo "setTtlSecondsAfterFinished-for-jobs.sh usage: setTtlSecondsAfterFinished-for-jobs.sh <namespace> [job-name]"
  exit 1
fi
NAMESPACE=$1
if [[ "$2" != "" ]]; then
  JOB=$2
  echo "kubectl -n ${NAMESPACE} patch job ${JOB} -p \"{\"spec\":{\"ttlSecondsAfterFinished\":${TTL_SECONDS_AFTER_FINISHED}}}\""
  kubectl -n ${NAMESPACE} patch job ${JOB} -p "{\"spec\":{\"ttlSecondsAfterFinished\":${TTL_SECONDS_AFTER_FINISHED}}}"
else
  JOBS=`kubectl -n ${NAMESPACE} get jobs --no-headers=true -o custom-columns=NAME:.metadata.name`
  echo -e "\nThe following jobs will be patched:\n\n${JOBS}\n"
  read -n 2 -p "Proceed patching jobs? [y/N]"
  if [[ "${REPLY}" != "y" ]]; then exit 1; fi
  for JOB in ${JOBS}; do
    echo "kubectl -n ${NAMESPACE} patch job ${JOB} -p \"{\"spec\":{\"ttlSecondsAfterFinished\":${TTL_SECONDS_AFTER_FINISHED}}}\""
    kubectl -n ${NAMESPACE} patch job ${JOB} -p "{\"spec\":{\"ttlSecondsAfterFinished\":${TTL_SECONDS_AFTER_FINISHED}}}"
  done
fi
