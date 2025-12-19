pipeline {

    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:

  - name: sonar-scanner
    image: sonarsource/sonar-scanner-cli:latest
    command: ["cat"]
    tty: true

  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["cat"]
    tty: true
    securityContext:
      runAsUser: 0
      readOnlyRootFilesystem: false
    env:
    - name: KUBECONFIG
      value: /kube/config
    volumeMounts:
    - name: kubeconfig-secret
      mountPath: /kube/config
      subPath: kubeconfig

  - name: dind
    image: docker:dind:latest
    args: ["--storage-driver=overlay2"]
    securityContext:
      privileged: true
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
    volumeMounts:
    - name: docker-config
      mountPath: /etc/docker/daemon.json
      subPath: daemon.json

  volumes:
  - name: docker-config
    configMap:
      name: docker-daemon-config
  - name: kubeconfig-secret
    secret:
      secretName: kubeconfig-secret
"""
        }
    }

    environment {

        // ---------- SONARQUBE CONFIG ----------
        PROJECT_KEY   = "2401180_E_Vaccination"
        PROJECT_NAME  = "2401180_E_Vaccination"
        SONAR_URL     = "http://my-sonarqube-sonarqube.sonarqube.svc.cluster.local:9000"
        SONAR_SOURCES = "."

        // ---------- DOCKER / NEXUS CONFIG ----------
        IMAGE_LOCAL   = "babyshield:latest"
        REGISTRY      = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085"
        REGISTRY_PATH = "2401180/e-vaccination-frontend"
        IMAGE_TAGGED  = "${REGISTRY}/${REGISTRY_PATH}:v${env.BUILD_NUMBER}"

        // ---------- KUBERNETES CONFIG ----------
        NAMESPACE     = "2401180"
    }

    stages {

        stage('Checkout Code') {
            steps {
                git url: 'https://github.com/khushi812/E-Vaccination-website.git',
                    branch: 'main'
            }
        }

        stage('Build Docker Image') {
            steps {
                container('dind') {
                    timeout(time: 5, unit: 'MINUTES') {
                        sh '''
                            echo "⏳ Waiting for Docker daemon..."
                            until docker info > /dev/null 2>&1; do
                              sleep 3
                            done

                            echo "🐳 Building Docker image..."
                            docker build -t ${IMAGE_LOCAL} .
                            docker image ls
                        '''
                    }
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                container('sonar-scanner') {
                    withCredentials([
                        string(
                            credentialsId: 'sonar-token-2401180',
                            variable: 'SONAR_TOKEN'
                        )
                    ]) {
                        sh '''
                            echo "🔍 Running SonarQube Analysis..."

                            sonar-scanner \
                              -Dsonar.projectKey=${PROJECT_KEY} \
                              -Dsonar.projectName=${PROJECT_NAME} \
                              -Dsonar.sources=${SONAR_SOURCES} \
                              -Dsonar.host.url=${SONAR_URL} \
                              -Dsonar.login=${SONAR_TOKEN} \
                              -Dsonar.sourceEncoding=UTF-8
                        '''
                    }
                }
            }
        }

        stage('Login to Docker Registry') {
            steps {
                container('dind') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'docker-registry-cred',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASS'
                        )
                    ]) {
                        sh '''
                            echo "⏳ Waiting for Docker daemon..."
                            until docker info > /dev/null 2>&1; do
                              sleep 3
                            done

                            echo "🔐 Logging into Docker Registry..."
                            echo "$DOCKER_PASS" | docker login ${REGISTRY} -u "$DOCKER_USER" --password-stdin
                        '''
                    }
                }
            }
        }

        stage('Tag & Push Image') {
            steps {
                container('dind') {
                    timeout(time: 5, unit: 'MINUTES') {
                        sh '''
                            echo "🏷 Tagging Docker image..."
                            docker tag ${IMAGE_LOCAL} ${IMAGE_TAGGED}

                            echo "📤 Pushing Docker image..."
                            docker push ${IMAGE_TAGGED}
                        '''
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    timeout(time: 5, unit: 'MINUTES') {
                        sh '''
                            echo "🚀 Deploying application to Kubernetes..."
                            kubectl apply -f babyshield-deployment.yaml

                            echo "⏳ Waiting for rollout..."
                            kubectl rollout status deployment/babyshield-deployment -n ${NAMESPACE}
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo "🎉 CI/CD Pipeline completed successfully!"
        }
        failure {
            echo "❌ CI/CD Pipeline failed. Please check logs."
        }
    }
}
