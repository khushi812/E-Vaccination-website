properties([
  pipelineTriggers([]),
  durabilityHint('PERFORMANCE_OPTIMIZED')
])

pipeline {

    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:

  - name: dind
    image: docker:dind
    securityContext:
      privileged: true
    args:
      - "--host=tcp://0.0.0.0:2375"
      - "--insecure-registry=nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085"   // 🔴 CHANGED (Nexus registry)
    env:
      - name: DOCKER_TLS_CERTDIR
        value: ""
    volumeMounts:
      - name: docker-storage
        mountPath: /var/lib/docker
      - name: workspace-volume
        mountPath: /home/jenkins/agent

  - name: sonar-scanner
    image: sonarsource/sonar-scanner-cli
    command: ["cat"]
    tty: true
    volumeMounts:
      - name: workspace-volume
        mountPath: /home/jenkins/agent

  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["cat"]
    tty: true
    securityContext:
      runAsUser: 0
    volumeMounts:
      - name: workspace-volume
        mountPath: /home/jenkins/agent

  volumes:
    - name: docker-storage
      emptyDir: {}
    - name: workspace-volume
      emptyDir: {}
"""
        }
    }

    options {
        skipDefaultCheckout()   // 🔴 CHANGED (manual git clone used)
    }

    environment {

        // 🔹 Project
        PROJECT_NAME = "E-Vaccination"
        DOCKER_IMAGE = "e-vaccination"    // 🔴 CHANGED (your Docker image name)

        // 🔹 SonarQube
        SONAR_PROJECT_KEY = "2401180_E_Vaccination"   // 🔴 CHANGED (must exist in SonarQube)
        SONAR_URL = "http://my-sonarqube-sonarqube.sonarqube.svc.cluster.local:9000"   // 🔴 CHANGED

        // 🔹 Nexus
        REGISTRY_HOST = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085"  // 🔴 CHANGED
        REGISTRY = "${REGISTRY_HOST}/2401180"   // 🔴 CHANGED (repo name in Nexus)

        // 🔹 Kubernetes
        NAMESPACE = "2401180"   // 🔴 CHANGED (your namespace)
    }

    stages {

        stage('Checkout Code') {
            steps {
                sh '''
                    echo "📥 Cloning source code..."
                    rm -rf *
                    git clone https://github.com/khushi812/E-Vaccination-website.git .   // 🔴 CHANGED (your repo)
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                container('dind') {
                    sh '''
                        echo "🐳 Building Docker image..."
                        docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} -t ${DOCKER_IMAGE}:latest .
                    '''
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                container('sonar-scanner') {
                    withCredentials([string(
                        credentialsId: 'sonar-token-2401180_E_vaccination',   // 🟢 REQUIRED in Jenkins
                        variable: 'SONAR_TOKEN'
                    )]) {
                        sh '''
                            echo "🔍 Running SonarQube analysis..."
                            sonar-scanner \
                              -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                              -Dsonar.sources=. \
                              -Dsonar.host.url=${SONAR_URL} \
                              -Dsonar.token=${SONAR_TOKEN}
                        '''
                    }
                }
            }
        }

        stage('Login to Nexus') {
            steps {
                container('dind') {
                    withCredentials([usernamePassword(
                        credentialsId: 'nexus-docker-creds',   // 🟢 REQUIRED in Jenkins
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASS'
                    )]) {
                        sh '''
                            echo "🔐 Logging into Nexus..."
                            docker login ${REGISTRY_HOST} -u $NEXUS_USER -p $NEXUS_PASS
                        '''
                    }
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                container('dind') {
                    sh '''
                        echo "📤 Pushing Docker images..."
                        docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${REGISTRY}/${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${REGISTRY}/${DOCKER_IMAGE}:latest

                        docker push ${REGISTRY}/${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${REGISTRY}/${DOCKER_IMAGE}:latest
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    sh '''
                        echo "🚀 Deploying to Kubernetes..."
                        kubectl apply -f deployment.yaml -n ${NAMESPACE}   // 🔴 CHANGED (file + namespace)
                        kubectl rollout status deployment/e-vaccination-deployment -n ${NAMESPACE}   // 🔴 CHANGED
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "🎉 E-Vaccination CI/CD Pipeline SUCCESS"
        }
        failure {
            echo "❌ E-Vaccination CI/CD Pipeline FAILED"
        }
        always {
            echo "🔁 Pipeline finished"
        }
    }
}
