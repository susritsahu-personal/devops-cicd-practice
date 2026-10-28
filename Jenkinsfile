pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                bat 'docker build -t devops-practice:jenkins-v1 .'
            }
        }

        stage('Verify Docker Image') {
            steps {
                bat 'docker image inspect devops-practice:jenkins-v1'
            }
        }
    }
}