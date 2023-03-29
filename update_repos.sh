#!/bin/bash
GIT_COMMIT_MESSAGE="Initial commit"
GITREPOS="repo1 repo2 repo3"
NAMESPACES="prod qa"
SCRIPTS="py r"

if [[ "$1" != "" && "$1" != "-h" && "$1" != "--help" ]]; then
  GIT_COMMIT_MESSAGE=$1
else
  echo -e "Usage: update_repos.sh 'commit message'"
  echo -e "The script will update project.ini and README.md in all bi-*** repos"
  exit 
fi

for GITREPO in ${GITREPOS}; do
  for NAMESPACE in ${NAMESPACES}; do
    for SCRIPT in ${SCRIPTS}; do
      export GITREPO NAMESPACE SCRIPT
      rm -f ../${GITREPO}-${NAMESPACE}-${SCRIPT}/README.md
      envsubst < README-${SCRIPT}.md >> ../${GITREPO}-${NAMESPACE}-${SCRIPT}/README.md
      cp -r ${SCRIPT}-project-a ../${GITREPO}-${NAMESPACE}-${SCRIPT}
      rm -f ../${GITREPO}-${NAMESPACE}-${SCRIPT}/${SCRIPT}-project-a/project.ini
      envsubst < ${SCRIPT}-project-a/project.ini >> ../${GITREPO}-${NAMESPACE}-${SCRIPT}/${SCRIPT}-project-a/project.ini
      cd ../${GITREPO}-${NAMESPACE}-${SCRIPT}
      if [[ -d .git ]]; then
      	git add README.md ${SCRIPT}-project-a/project.ini
     	git commit -m "${GIT_COMMIT_MESSAGE}"
      	git push
      else
        git init
        git add -A
        git commit -m "${GIT_COMMIT_MESSAGE}"
        git remote add origin ssh://git@git.example.com:7999/${GITREPO}_${NAMESPACE}_${SCRIPT}.git
        git push -u origin master
      fi
      cd -
    done
  done
done
