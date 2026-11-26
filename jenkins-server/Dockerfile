# Jenkins LTS + Docker CLI (it uses the host's Docker through the mounted socket)
FROM jenkins/jenkins:lts
USER root
COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker:cli /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
