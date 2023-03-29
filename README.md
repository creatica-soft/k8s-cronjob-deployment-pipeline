# k8s-cronjob-deployment-pipeline
k8s python and R cronjob worlload deployment pipeline using bash script

deploy.sh is a main bash script that could be executed periodically to pull changes in developer git repos, build a docker image if necessary and store it in nexus repository, then create a k8s cronjob based on variables specified in project.ini file.

It meant to be shared among different teams, which code their workloads in python and R. Therefore, there are two cronjob templates py-cronjob.yaml and r-cronjob.yaml and two Dockerfile templates py-Dockerfile.template and r-Dockerfile.template. There are also two entrypoint templates: py-main.template and r-main.template.

Script update_repos.sh could be used to populate repos with py-project-a and r-project-a folders, which contain project.ini sample file as well as README.md file with instructions on how to clone these sample projects.

