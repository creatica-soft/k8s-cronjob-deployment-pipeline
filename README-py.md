This repository is meant to be used for deploying ${NAMESPACE} python scripts into
Kubernetes cluster via Kubernetes cronjobs and custom python-3.7 docker images.
THE DEPLOYMENT SCRIPT RUNS ON THE BUILD SERVER EVERY 5 MINUTES
BUT ONLY ONE DEPLOY PROCESS IS ALLOWED, SO IF THE FIRST PROCESS HAS NOT FINISHED, THE NEXT ONE WILL BE SKIPPED.

Note that NFS storage is mounted under /data. /data/${GITREPO}-${NAMESPACE}-${SCRIPT} will be available for read-write.

1. Begin with cloning this repo 

```
git clone https://git.example.com/local/${GITREPO}_${NAMESPACE}_${SCRIPT}.git
cd ${GITREPO}_${NAMESPACE}_${SCRIPT}
```

  - For production environment, create a branch

```
git checkout -b <branch-name>
```

  - For QA environment, just work on the master branch - no pull requests are required

2. Copy ${SCRIPT}-project-a folder (please do not rename or delete it!)

```
cp -r ${SCRIPT}-project-a <project-name>
```

IMPORTANT: folder name must consist of lower case alphanumeric characters or `-` ONLY
and must start and end with an alphanumeric character (e.g. `example-com`), regex used
for validation is `[a-z0-9]([-a-z0-9]*[a-z0-9])?`

3. Please make sure you import the service account credentials from system variables to python environment 
(Variable values will be retrieved from Kubernetes secrets at runtime).
Currently configured system variables are: USERNAME, PASSWORD.

```
import os
username = os.environ.get('USERNAME')
password = os.environ.get('PASSWORD')
```

4. Place all your scripts into the folder `<project-name>`, including pip requirements.txt file if needed
5. Modify environment variables in project.ini file to suite your needs
6. Commit your changes

```
git add -A
git commit -m "initial commit"
```

7. For production enviroment, push your changes to the remote branch

```
git push origin <branch-name>
```

8. Then create a pull request to merge your branch with the master using GUI:

```
https://git.example.com/local/${GITREPO}_${NAMESPACE}_${SCRIPT}/pull-requests
```

   - or from a command line:

```
git request-pull master <branch-name>
```

Once your pull request is reviewed, and your changes are merged to the master branch,
the build server will pull them in, build a custom docker image, save it in the nexus repo
and deploy your Kubernetes cronjob

Later you can modify the cronjob schedule, python docker image or python scripts as well as
delete the cronjob, which will delete the project from the master branch. All these
changes will require pull requests to merge them into the master branch.

7. For QA environment just push your commits to the master branch

```
git push
```

