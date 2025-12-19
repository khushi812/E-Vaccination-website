pipeline {

  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:

  - name: kaniko
    image: gcr.io/kaniko-project/executor:latest
    command:
      - /busybox/cat
    tty: true
    volumeMounts:
      - name: docker-config
        mountPath: /kaniko/.docker/

  - name: sonar-scanner
    image: sonarsource/sonar-scanner-cli:5
    command: ["cat"]
    tty: true

  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["cat"]
    tty: true
    env:
      - name: KUBECONFIG
        value: /kube/config
    volumeMounts:
      - name: kubeconfig-secret
        mountPath: /kube/config
        subPath: kubeconfig

  volumes:
  - name: docker-config
    secret:
      secretName: docker-registry-secret
  - name: kubeconfig-secret
    secret:
      secretName: kubeconfig-secret
"""
    }
  }

  environment {
    PROJECT_KEY  = "2401180_E_Vaccination"
    PROJECT_NAME = "2401180_E_Vaccination"
    SONAR_URL    = "http://my-sonarqube-sonarqube.sonarqube.svc.cluster.local:9000"

    REGISTRY     = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085"
    IMAGE_NAME   = "2401180/e-vaccination-frontend"
    IMAGE_TAG    = "v${BUILD_NUMBER}"

    NAMESPACE    = "2401180"
  }

  stages {

    stage('Checkout Code') {
      steps {
        git branch: 'main',
            url: 'https://github.com/khushi812/E-Vaccination-website.git'
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
              -Dsonar.sources=. \
              -Dsonar.host.url=${SONAR_URL} \
              -Dsonar.login=${SONAR_TOKEN}
            '''
          }
        }
      }
    }

    stage('Build & Push Image (Kaniko)') {
      steps {
        container('kaniko') {
          sh '''
            /kaniko/executor \
            --dockerfile=Dockerfile \
            --context=$WORKSPACE \
            --destination=${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
          '''
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        container('kubectl') {
          sh '''
            kubectl apply -f babyshield-deployment.yaml -n ${NAMESPACE}
            kubectl rollout status deployment/babyshield-deployment -n ${NAMESPACE}
          '''
        }
      }
    }
  }
}
