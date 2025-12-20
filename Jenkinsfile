pipeline {

    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:

  - name: sonar-scanner
    image: sonarsource/sonar-scanner-cli
    command: ["cat"]
    tty: true

  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["cat"]
    tty: true
    securityContext:
      runAsUser: 0
    env:
    - name: KUBECONFIG
      value: /kube/config
    volumeMounts:
    - name: kubeconfig-secret
      mountPath: /kube/config
      subPath: kubeconfig

  - name: dind
    image: docker:24-dind
    securityContext:
      privileged: true
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
    command: ["dockerd-entrypoint.sh"]
    args:
    - --host=unix:///var/run/docker.sock
    - --storage-driver=overlay2
    volumeMounts:
    - name: docker-storage
      mountPath: /var/lib/docker

  volumes:
  - name: docker-storage
    emptyDir: {}
  - name: kubeconfig-secret
    secret:
      secretName: kubeconfig-secret
'''
        }
    }

    environment {

        // ---------- SONAR ----------
        PROJECT_KEY   = "2401180_E_vaccination"
        PROJECT_NAME  = "2401180_E_vaccination"
        SONAR_URL     = "http://my-sonarqube-sonarqube.sonarqube.sonarqube.svc.cluster.local:9000"
        SONAR_SOURCES = "."

        // ---------- DOCKER / NEXUS ----------
        IMAGE_LOCAL   = "babyshield:latest"
        REGISTRY      = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085"
        REGISTRY_PATH = "2401180/babyshield"
        IMAGE_TAGGED  = "${REGISTRY}/${REGISTRY_PATH}:v${BUILD_NUMBER}"

        // ---------- K8S ----------
        NAMESPACE     = "2401180"
    }

    stages {

        stage('Checkout Code') {
            steps {
                git url: 'https://github.com/khushi812/E-Vaccination-website.git', branch: 'main'
            }
        }

        stage('Build Docker Image') {
            steps {
                container('dind') {
                    sh '''
                        until docker info > /dev/null 2>&1; do sleep 3; done
                        docker build -t ${IMAGE_LOCAL} .
                    '''
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                container('sonar-scanner') {
                    withCredentials([string(credentialsId: 'sonar-token-2401180', variable: 'SONAR_TOKEN')]) {
                        sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=${PROJECT_KEY} \
                          -Dsonar.projectName=${PROJECT_NAME} \
                          -Dsonar.sources=${SONAR_SOURCES} \
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
                    sh '''
                        until docker info > /dev/null 2>&1; do sleep 3; done
                        docker login ${REGISTRY} -u admin -p Changeme@2025
                    '''
                }
            }
        }

        stage('Tag & Push Image') {
            steps {
                container('dind') {
                    sh '''
                        docker tag ${IMAGE_LOCAL} ${IMAGE_TAGGED}
                        docker push ${IMAGE_TAGGED}
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    sh '''
                        set -e
                        echo "🚀 Deploying BabyShield..."

                        kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

                        kubectl apply -f babyShield-deployment.yaml -n ${NAMESPACE}

                        kubectl set image deployment/babyshield-deployment \
                          babyshield-container=${IMAGE_TAGGED} \
                          -n ${NAMESPACE}

                        kubectl rollout status deployment/babyshield-deployment -n ${NAMESPACE}
                    '''
                }
            }
        }
    }
}
