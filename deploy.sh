#!/usr/bin/bash
PID_FILE=~/deploy.pid
BASENAME=`basename $0`
if [[ -f ${PID_FILE} ]]; then
  PID=`cat ${PID_FILE}`
  COMM=`ps -o comm -hp ${PID}`
  if [[ "${COMM}" == "${BASENAME}" ]]; then
    echo "${BASENAME} is already running with pid ${PID}, quitting..."
    exit 1
  fi
fi
echo $$ > ${PID_FILE}

DOCKER_SERVER="nexus.example.com:8443"
DOCKER_REPO="docker-repo"
DOCKER_LOGIN="docker"
DOCKER_BASE_IMAGE_PY="docker-python:1.9"
DOCKER_BASE_IMAGE_R="r:4.1.2-2"
NEXUS_URL="https://nexus.example.com"
WORKER_NODE1="kube-minion-1"
WORKER_NODE2="kube-minion-2"
WORKER_NODE3="kube-minion-3"
MASTER_REPO="git-repo"
EMAIL_BCC="PROJECTS_LOGS@example.com"
PASSWORD=`kubectl get secrets docker -o json|jq ".data.password"|tr -d '"'|base64 -d`
export NEXUS_URL DOCKER_SERVER DOCKER_REPO DOCKER_LOGIN PASSWORD WORKER_NODE1 WORKER_NODE2 WORKER_NODE3 EMAIL_BCC

GITREPOS="repo1 repo2 repo3"
NAMESPACES="prod qa"
SCRIPTS="py r"
TEAM_A_SA_UID="123456789"
TEAM_A_SA_USER="User1"
TEAM_A_USERS_GID="987654321"
TEAM_A_USERS_GROUP="Group1"
TEAM_B_SA_UID="234567890"
TEAM_B_SA_USER="User2"
TEAM_B_USERS_GID="876543210"
TEAM_B_USERS_GROUP="Group2"

function delete_cronjob {
      echo -e "kubectl -n ${NAMESPACE} delete cronjob ${JOBNAME}\r" >> ${LOG_FILE}
      kubectl -n ${NAMESPACE} delete cronjob ${JOBNAME} >> ${LOG_FILE} 2>&1
      echo -e "\r" >> ${LOG_FILE}
      sleep 15s
      NEXUS_QUERY_STRING="${NEXUS_URL}/service/rest/v1/search?repository=${DOCKER_REPO}&name=repository/${DOCKER_REPO}/${DOCKER_IMAGE}&version=${VERSION}"
      echo -e "COMPONENT_ID=\`curl -u docker -X GET ${NEXUS_QUERY_STRING}|jq \".items[].id\"|tr -d \"\`\r" >> ${LOG_FILE}
      COMPONENT_ID=`curl -u ${DOCKER_LOGIN}:$PASSWORD -X GET ${NEXUS_QUERY_STRING}|jq ".items[].id"|tr -d '"'`
      NEXUS_QUERY_STRING="${NEXUS_URL}/service/rest/v1/components/${COMPONENT_ID}"
      echo -e "curl -sSi -u ${DOCKER_LOGIN} -X DELETE ${NEXUS_QUERY_STRING}\r" >> ${LOG_FILE}
      curl -sSi -u ${DOCKER_LOGIN}:$PASSWORD -X DELETE ${NEXUS_QUERY_STRING} >> ${LOG_FILE} 2>&1
      echo -e "ssh ${WORKER_NODE1} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION}\r" >> ${LOG_FILE}
      ssh ${WORKER_NODE1} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION} >> ${LOG_FILE} 2>&1
      echo -e "\r" >> ${LOG_FILE}
      echo -e "ssh ${WORKER_NODE2} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION}\r" >> ${LOG_FILE}
      ssh ${WORKER_NODE2} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION} >> ${LOG_FILE} 2>&1
      echo -e "\r" >> ${LOG_FILE}
      echo -e "ssh ${WORKER_NODE3} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION}\r" >> ${LOG_FILE}
      ssh ${WORKER_NODE3} sudo crictl -r unix:///run/containerd/containerd.sock rmi ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${VERSION} >> ${LOG_FILE} 2>&1
      echo -e "\r" >> ${LOG_FILE}
}

for GITREPO in ${GITREPOS}; do
	case "${GITREPO}" in 
        "teamA")
                SA_UID="${TEAM_A_SA_UID}"
                USERS_GID="${TEAM_A_USERS_GID}"
                SA_USER="${TEAM_A_SA_USER}"
                SA_GROUP="${TEAM_A_USERS_GROUP}"
                ;;
        "teamB")
                SA_UID="${TEAM_B_SA_UID}"
                USERS_GID="${TEAM_B_USERS_GID}"
                SA_USER="${TEAM_B_SA_USER}"
                SA_GROUP="${TEAM_B_USERS_GROUP}"
                ;;
	esac
	export GITREPO SA_UID USERS_GID SA_USER SA_GROUP
	for NAMESPACE in ${NAMESPACES}; do
		export NAMESPACE
		for SCRIPT in ${SCRIPTS}; do
			export SCRIPT
			cd ~/${GITREPO}-${NAMESPACE}-${SCRIPT}
   echo "${GITREPO}-${NAMESPACE}-${SCRIPT}"
			git reset --hard -q
			DATETIME=`date`
			sleep 1s
			git pull
			PROJECTS=`find . -maxdepth 2 -mindepth 2 -newermt "${DATETIME}" -name project.ini|cut -f2 -d"/"|tr '[:blank:]' '-'`

			for PROJECT in ${PROJECTS}; do
			  if [[ "${PROJECT}" == "${SCRIPT}-project-a" ]]; then
				continue
			  fi
			  cd ${PROJECT}
			  if [[ ! -d ~/logs/${GITREPO}-${NAMESPACE}-${SCRIPT} ]]; then 
				mkdir -p ~/logs/${GITREPO}-${NAMESPACE}-${SCRIPT}; 
			  fi
			  export LOG_FILE=~/logs/${GITREPO}-${NAMESPACE}-${SCRIPT}/${PROJECT}.txt
			  if [[ -f ${LOG_FILE} ]]; then
				rm -f ${LOG_FILE}
			  fi
			  echo -e "source project.ini\r" >> ${LOG_FILE}
  			  source project.ini
			  if [[ "${EMAIL_CC}" != "" ]]; then
				EMAIL_CC="-c ${EMAIL_CC}"
			  fi
			  if [[ "${EMAIL_FROM}" != "" ]]; then
				EMAIL_FROM="-r ${EMAIL_FROM}"
			  fi
			  JOBNAME=`echo "${GITREPO}-${NAMESPACE}-${SCRIPT}-${PROJECT}"|tr '[:upper:]' '[:lower:]'|tr '[:punct:]' '-'`
			  DOCKER_IMAGE="image-${JOBNAME}"
			  if [[ "${DOCKER_BASE_IMAGE}" == "" ]]; then
			  	if [[ "${SCRIPT}" == "py" ]]; then
			  		DOCKER_BASE_IMAGE=${DOCKER_BASE_IMAGE_PY}
			  	else	
			  		DOCKER_BASE_IMAGE=${DOCKER_BASE_IMAGE_R}
			  	fi	
			  fi
			  if [[ "${MIN_CPU}" == "" && "${MAX_CPU}" != "" ]]; then
				MIN_CPU=${MAX_CPU}
			  fi
			  if [[ "${MIN_CPU}" != "" && "${MAX_CPU}" == "" ]]; then
				MAX_CPU=${MIN_CPU}
			  fi
			  if [[ "${MIN_CPU}" == "" && "${MAX_CPU}" == "" ]]; then
				MIN_CPU="1000m"
				MAX_CPU="1000m"
			  fi
			  if [[ "${MIN_RAM}" == "" && "${MAX_RAM}" != "" ]]; then
				MIN_RAM=${MAX_RAM}
			  fi
			  if [[ "${MIN_RAM}" != "" && "${MAX_RAM}" == "" ]]; then
				MAX_RAM=${MIN_RAM}
			  fi
			  if [[ "${MIN_RAM}" == "" && "${MAX_RAM}" == "" ]]; then
				MIN_RAM="500Mi"
				MAX_RAM="1000Mi"
			  fi
			  DELETE_CRONJOB=`echo ${DELETE_CRONJOB}|tr [:upper:] [:lower:]`
			  export PROJECT JOBNAME DOCKER_BASE_IMAGE DOCKER_IMAGE DOCKER_IMAGE_VERSION MIN_CPU MIN_RAM MAX_CPU MAX_RAM CRONJOB_SCHEDULE MAIN_SCRIPT R_LIBRARIES EMAIL_TO EMAIL_CC EMAIL_FROM
			  if [[ ! ${JOBNAME} =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
				echo -e "DATETIME=${DATETIME}\r" >> ${LOG_FILE}
				echo -e "PROJECT=${PROJECT}\r" >> ${LOG_FILE}
				echo -e "JOBNAME=${JOBNAME}\r" >> ${LOG_FILE}
				echo -e 'Project folder name does not match DNS label (RFC1035/RFC1123). It must be lower case alphanumeric string with a maximum of 63 characters. "-" is allowed everywhere except the first and last character. It must match this regular expression ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$\r' >> ${LOG_FILE}
				cd ..
				echo -e "git rm -rf ${PROJECT}\r" >> ${LOG_FILE}
				git rm -rf ${PROJECT} >> ${LOG_FILE} 2>&1
				if [[ -d ${PROJECT} ]]; then
				  echo -e "rm -rf ${PROJECT}\r" >> ${LOG_FILE}
				  rm -rf ${PROJECT} >> ${LOG_FILE} 2>&1
                                fi
				echo -e "git commit -m \"deleted project ${PROJECT}\"\r" >> ${LOG_FILE}
				git commit -m "deleted project ${PROJECT}" >> ${LOG_FILE} 2>&1
				echo -e "git push\r"  >> ${LOG_FILE}
				git push >> ${LOG_FILE} 2>&1
				if [[ "${EMAIL_TO}" != "" ]]; then
				  echo -e "echo -e \"Hi, attached is the report of ${SCRIPT} your cronjob deployment\" | mail -s \"${PROJECT} error in project folder name\" -a ${LOG_FILE} -b ${EMAIL_BCC} ${EMAIL_FROM} ${EMAIL_CC} ${EMAIL_TO}\r" >> ${LOG_FILE}
				  echo -e "Hi, attached is the report of your ${SCRIPT} cronjob deployment" | mail -s "${PROJECT} error in project folder name" -a ${LOG_FILE} -b ${EMAIL_BCC} ${EMAIL_FROM} ${EMAIL_CC} ${EMAIL_TO}
				fi
				unset LOG_FILE PROJECT JOBNAME DOCKER_BASE_IMAGE DOCKER_IMAGE DOCKER_IMAGE_VERSION MIN_CPU MIN_RAM MAX_CPU MAX_RAM MAIN_SCRIPT R_LIBRARIES CRONJOB_SCHEDULE EMAIL_TO EMAIL_CC EMAIL_FROM DELETE_CRONJOB
				continue
			  fi
			  echo -e "DATETIME=${DATETIME}\r" >> ${LOG_FILE}
			  echo -e "PROJECT=${PROJECT}\r" >> ${LOG_FILE}
			  echo -e "JOBNAME=${JOBNAME}\r" >> ${LOG_FILE}
			  echo -e "DOCKER_BASE_IMAGE=${DOCKER_BASE_IMAGE}\r" >> ${LOG_FILE}
			  echo -e "DOCKER_IMAGE=${DOCKER_IMAGE}\r" >> ${LOG_FILE}
			  echo -e "DOCKER_IMAGE_VERSION=${DOCKER_IMAGE_VERSION}\r" >> ${LOG_FILE}
			  echo -e "MIN_CPU=${MIN_CPU}\r" >> ${LOG_FILE}
			  echo -e "MIN_RAM=${MIN_RAM}\r" >> ${LOG_FILE}
			  echo -e "MAX_CPU=${MAX_CPU}\r" >> ${LOG_FILE}
			  echo -e "MAX_RAM=${MAX_RAM}\r" >> ${LOG_FILE}
			  echo -e "CRONJOB_SCHEDULE=${CRONJOB_SCHEDULE}\r" >> ${LOG_FILE}
			  echo -e "MAIN_SCRIPT=${MAIN_SCRIPT}\r" >> ${LOG_FILE}
			  echo -e "R_LIBRARIES=${R_LIBRARIES}\r" >> ${LOG_FILE}
			  echo -e "EMAIL_TO=${EMAIL_TO}\r" >> ${LOG_FILE}
			  echo -e "EMAIL_CC=${EMAIL_CC}\r" >> ${LOG_FILE}
                          echo -e "EMAIL_FROM=${EMAIL_FROM}\r" >> ${LOG_FILE}
			  echo -e "DELETE_CRONJOB=${DELETE_CRONJOB}\r" >> ${LOG_FILE}
			  if [[ ${DELETE_CRONJOB} == "true" ]]; then
				export VERSION=${DOCKER_IMAGE_VERSION}
				delete_cronjob
				cd ..
				echo -e "git rm -rf ${PROJECT}\r" >> ${LOG_FILE}
				git rm -rf ${PROJECT} >> ${LOG_FILE} 2>&1
				if [[ -d ${PROJECT} ]]; then
				  echo -e "rm -rf ${PROJECT}\r" >> ${LOG_FILE}
				  rm -rf ${PROJECT} >> ${LOG_FILE} 2>&1
                                fi
				echo -e "git commit -m \"deleted project ${PROJECT}\"\r" >> ${LOG_FILE}
				git commit -m "deleted project ${PROJECT}" >> ${LOG_FILE} 2>&1
				echo -e "git push\r"  >> ${LOG_FILE}
				git push >> ${LOG_FILE} 2>&1
				if [[ "${EMAIL_TO}" != "" ]]; then
				  echo -e "echo -e \"Hi, attached is the report of your ${SCRIPT} cronjob deployment\" | mail -s \"${PROJECT} Kubernetes cronjob deletion results\" -a ${LOG_FILE} -b ${EMAIL_BCC} ${EMAIL_FROM} ${EMAIL_CC} ${EMAIL_TO}\r" >> ${LOG_FILE}
				  echo -e "Hi, attached is the report of your ${SCRIPT} cronjob deployment" | mail -s "${PROJECT} Kubernetes cronjob deletion results" -a ${LOG_FILE} -b ${EMAIL_BCC} ${EMAIL_FROM} ${EMAIL_CC} ${EMAIL_TO}
				fi
				unset LOG_FILE JOBNAME VERSION PROJECT DOCKER_BASE_IMAGE DOCKER_IMAGE DOCKER_IMAGE_VERSION MIN_CPU MIN_RAM MAX_CPU MAX_RAM MAIN_SCRIPT R_LIBRARIES CRONJOB_SCHEDULE EMAIL_TO EMAIL_CC EMAIL_FROM DELETE_CRONJOB
				continue
			  fi
			  NEXUS_QUERY_STRING="${NEXUS_URL}/service/rest/v1/search?repository=${DOCKER_REPO}&name=repository/${DOCKER_REPO}/${DOCKER_IMAGE}"
			  export VERSION=`curl -u ${DOCKER_LOGIN}:$PASSWORD -X GET ${NEXUS_QUERY_STRING}|jq ".items[0].version"|tr -d '"'`
			  ERROR=0
			  echo -e "VERSION=${VERSION}\r"  >> ${LOG_FILE}
			  if [[ "${VERSION}" != "${DOCKER_IMAGE_VERSION}" ]]; then
				if [[ "${VERSION}" != "null" ]]; then
				  delete_cronjob
				fi
				echo -e "envsubst < ../../${MASTER_REPO}/${SCRIPT}-Dockerfile.template > Dockerfile\r" >> ${LOG_FILE}
				envsubst < ../../${MASTER_REPO}/${SCRIPT}-Dockerfile.template > Dockerfile
				echo -e "envsubst '\${SA_USER}\${SA_GROUP}\${MAIN_SCRIPT}\${EMAIL_TO}\${EMAIL_BCC}\${EMAIL_CC}\${EMAIL_FROM}\${PROJECT}' < ../../${MASTER_REPO}/${SCRIPT}-main.template > main.sh\r" >> ${LOG_FILE}
				envsubst '${SA_USER}${SA_GROUP}${MAIN_SCRIPT}${EMAIL_TO}${EMAIL_FROM}${EMAIL_BCC}${EMAIL_CC}${PROJECT}' < ../../${MASTER_REPO}/${SCRIPT}-main.template > main.sh
				echo -e "chmod 755 main.sh\r" >> ${LOG_FILE}
				chmod 755 main.sh
				echo -e "tar -zcf archive.tar.gz *\r" >> ${LOG_FILE}
				tar zcf archive.tar.gz * >> ${LOG_FILE} 2>&1
				echo -e "docker build -t=\"${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION}\" .\r" >> ${LOG_FILE}
				sudo docker build -t="${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION}" . >> ${LOG_FILE} 2>&1
				if (( $? == 0 )); then
				  echo -e "sudo docker tag ${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION} ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION}\r" >> ${LOG_FILE}
				  sudo docker tag ${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION} ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION} >> ${LOG_FILE} 2>&1
				  echo -e "sudo docker login -u docker ${DOCKER_SERVER}\r" >> ${LOG_FILE}
				  sudo docker login -u docker -p ${PASSWORD} ${DOCKER_SERVER} >> ${LOG_FILE} 2>&1
				  echo -e "sudo docker push ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION}\r" >> ${LOG_FILE}
				  sudo docker push ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION} >> ${LOG_FILE} 2>&1
				  if (( $? != 0 )); then
					ERROR=1
				  fi
				  echo -e "sudo docker logout ${DOCKER_SERVER}\r" >> ${LOG_FILE}
				  sudo docker logout ${DOCKER_SERVER} >> ${LOG_FILE} 2>&1
				  echo -e "docker image rm ${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION}\r" >> ${LOG_FILE}
				  sudo docker image rm ${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION} >> ${LOG_FILE} 2>&1
				  echo -e "docker image rm ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION}\r" >> ${LOG_FILE}
				  sudo docker image rm ${DOCKER_SERVER}/repository/${DOCKER_REPO}/${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION} >> ${LOG_FILE} 2>&1
				else
				  ERROR=1
				fi
				echo -e "rm -f archive.tar.gz\r" >> ${LOG_FILE}
				rm -f archive.tar.gz >> ${LOG_FILE} 2>&1
			  fi
			  if (( ${ERROR} == 0 )); then
			    if [[ "${GITREPO}" == "fawkes" || "${GITREPO}" == "runa" ]]; then
      			      echo -e "kubectl -n ${NAMESPACE} delete cronjob ${JOBNAME}\r" >> ${LOG_FILE}
      			      kubectl -n ${NAMESPACE} delete cronjob ${JOBNAME} >> ${LOG_FILE} 2>&1
			      echo -e "envsubst < ../../${MASTER_REPO}/${GITREPO}-${SCRIPT}-cronjob.yaml |kubectl -n ${NAMESPACE} apply -f -\r" >> ${LOG_FILE}
			      envsubst < ../../${MASTER_REPO}/${GITREPO}-${SCRIPT}-cronjob.yaml |kubectl -n ${NAMESPACE} apply -f - >> ${LOG_FILE} 2>&1
			    else
      			      echo -e "kubectl -n ${NAMESPACE} delete cronjob ${JOBNAME}\r" >> ${LOG_FILE}
      			      kubectl -n ${NAMESPACE} delete cronjob ${JOBNAME} >> ${LOG_FILE} 2>&1
			      echo -e "envsubst < ../../${MASTER_REPO}/${SCRIPT}-cronjob.yaml |kubectl -n ${NAMESPACE} apply -f -\r" >> ${LOG_FILE}
			      envsubst < ../../${MASTER_REPO}/${SCRIPT}-cronjob.yaml |kubectl -n ${NAMESPACE} apply -f - >> ${LOG_FILE} 2>&1
			    fi
			    if (( $? != 0 )); then
		              ERROR=1
			    fi
                          fi
		          if [[ "${EMAIL_TO}" != "" ]]; then
			    if (( ${ERROR} == 0 )); then
                              RESULT="succeeded"
                            else
                              RESULT="failed"
                            fi
			    echo -e "echo -e \"Hi, attached is the report of your ${SCRIPT} cronjob deployment\" | mail -s \"${PROJECT} deployment ${RESULT}\" -a ${LOG_FILE} -b ${EMAIL_BCC} ${EMAIL_FROM} ${EMAIL_CC} ${EMAIL_TO}\r" >> ${LOG_FILE}
			    echo -e "Hi, attached is the report of your ${SCRIPT} cronjob deployment" | mail -s "${PROJECT} deployment ${RESULT}" -a ${LOG_FILE} -b ${EMAIL_BCC} ${EMAIL_FROM} ${EMAIL_CC} ${EMAIL_TO}
		   	  fi
			  unset LOG_FILE JOBNAME DOCKER_IMAGE VERSION PROJECT DOCKER_BASE_IMAGE DOCKER_IMAGE_VERSION MIN_CPU MIN_RAM MAX_CPU MAX_RAM MAIN_SCRIPT R_LIBRARIES CRONJOB_SCHEDULE EMAIL_TO EMAIL_CC EMAIL_FROM DELETE_CRONJOB 
			  cd ..
		     done
		     cd ..
		  done
	  done
	  unset SA_UID USERS_GID SA_USER SA_GROUP
done

echo -e "unset NEXUS_URL DOCKER_REPO DOCKER_LOGIN PASSWORD WORKER_NODE1 WORKER_NODE2 WORKER_NODE3"
unset NEXUS_URL DOCKER_SERVER DOCKER_REPO DOCKER_LOGIN PASSWORD WORKER_NODE1 WORKER_NODE2 WORKER_NODE3 EMAIL_BCC
