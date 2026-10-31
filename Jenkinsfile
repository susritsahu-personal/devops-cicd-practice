pipeline {
    agent any

    environment {
        PATH = "C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin;${env.PATH}"
    }

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

        stage('Deploy Docker Container') {
            steps {
                bat '''
                    docker ps -a --filter "name=^/devops-practice-jenkins$" --format "{{.Names}}" | findstr /x "devops-practice-jenkins" >nul
                    if not errorlevel 1 (
                        echo ERROR: Deployment container name already exists. Stopping deployment to protect existing containers.
                        exit /b 1
                    )

                    docker run -d --name devops-practice-jenkins -p 8085:80 devops-practice:jenkins-v1
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                bat 'docker ps --filter "name=^/devops-practice-jenkins$"'
            }
        }
    }
}