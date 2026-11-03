pipeline {
    agent any

    environment {
        PATH+DOCKER = 'C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin'
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

        stage('Deploy Candidate Container') {
            steps {
                bat '''
                    @echo off

                    docker container inspect devops-practice-candidate >nul 2>&1
                    if not errorlevel 1 (
                        echo ERROR: Candidate container already exists.
                        exit /b 1
                    )

                    echo Checking whether port 8086 is available...
                    powershell -NoProfile -Command "if (Get-NetTCPConnection -LocalPort 8086 -State Listen -ErrorAction SilentlyContinue) { exit 1 }"
                    if errorlevel 1 (
                        echo ERROR: Port 8086 is already in use.
                        exit /b 1
                    )

                    echo Deploying candidate container...
                    docker run -d --name devops-practice-candidate -p 8086:80 devops-practice:jenkins-v1

                    if errorlevel 1 (
                        echo ERROR: Candidate deployment failed.
                        exit /b 1
                    )

                    echo Candidate container created successfully.
                '''
            }
        }

        stage('Verify Candidate Deployment') {
            steps {
                bat '''
                    @echo off
                    docker container inspect --format "{{.State.Running}}" devops-practice-candidate | findstr /x "true" >nul

                    if errorlevel 1 (
                        echo ERROR: Candidate container is not running.
                        exit /b 1
                    )

                    echo Candidate container is running successfully.
                '''
            }
        }

        stage('HTTP Health Check') {
            steps {
                script {
                    def statusCode = bat(
                        script: '@curl.exe -s -o NUL -w "%%{http_code}" http://localhost:8086',
                        returnStdout: true
                    ).trim()

                    echo "Website HTTP status: ${statusCode}"

                    if (statusCode != '200') {
                        error("Health check failed! Expected HTTP 200, received ${statusCode}")
                    }

                    echo 'Health check PASSED: Website returned HTTP 200'
                }
            }
        }
    }
}