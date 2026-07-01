// CI/CD pipeline: build Docker image with Kaniko, push to Amazon ECR,
// bump the image tag in the Helm chart's values.yaml and push to main.
// Argo CD then detects the Git change and auto-syncs the cluster.
pipeline {
  agent {
    kubernetes {
      // Pod template declared via JCasC in the Jenkins Helm values.
      label 'kaniko-git'
      defaultContainer 'kaniko'
    }
  }

  environment {
    AWS_REGION    = "${env.AWS_REGION ?: 'us-west-2'}"
    ECR_REGISTRY  = "${env.ECR_REGISTRY}"                  // <acct>.dkr.ecr.<region>.amazonaws.com
    ECR_REPO      = 'lesson-7-ecr'
    IMAGE_TAG     = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'manual'}"
    // Repo that holds the Helm chart Argo CD watches.
    CONFIG_REPO   = 'github.com/loha/devops_ci_cd.git'
    CHART_VALUES  = 'charts/django-app/values.yaml'
    GIT_BRANCH    = 'main'
  }

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  stages {
    stage('Checkout') {
      steps {
        container('git') {
          checkout scm
        }
      }
    }

    stage('Build & Push image (Kaniko)') {
      steps {
        container('kaniko') {
          sh '''
            set -eu
            IMAGE="${ECR_REGISTRY}/${ECR_REPO}"
            echo "Building ${IMAGE}:${IMAGE_TAG}"
            /kaniko/executor \
              --context "$(pwd)" \
              --dockerfile "$(pwd)/Dockerfile" \
              --destination "${IMAGE}:${IMAGE_TAG}" \
              --destination "${IMAGE}:latest" \
              --cache=true
          '''
        }
      }
    }

    stage('Update Helm chart tag & push') {
      steps {
        container('git') {
          withCredentials([usernamePassword(
            credentialsId: 'github-token',
            usernameVariable: 'GIT_USER',
            passwordVariable: 'GIT_TOKEN')]) {
            sh '''
              set -eu
              git config user.email "ci@jenkins.local"
              git config user.name  "jenkins-ci"

              # Bump the image tag in the chart values (portable POSIX BRE).
              sed -i "s|^\\([[:space:]]*tag:\\).*|\\1 ${IMAGE_TAG}|" "${CHART_VALUES}"
              echo "Updated ${CHART_VALUES}:"
              grep -n "tag:" "${CHART_VALUES}" || true

              git add "${CHART_VALUES}"
              git commit -m "ci: bump django-app image tag to ${IMAGE_TAG} [skip ci]" || {
                echo "No changes to commit"; exit 0;
              }
              git push "https://${GIT_USER}:${GIT_TOKEN}@${CONFIG_REPO}" "HEAD:${GIT_BRANCH}"
            '''
          }
        }
      }
    }
  }

  post {
    success {
      echo "Image pushed and chart updated to tag ${IMAGE_TAG}. Argo CD will sync."
    }
    failure {
      echo 'Pipeline failed.'
    }
  }
}
