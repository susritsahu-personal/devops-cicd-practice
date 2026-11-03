
pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME = 'devops-practice:jenkins-v1'
        TEST_CONTAINER = 'devops-practice-test'
        TEST_PORT = '8087'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                withEnv(['PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin']) {
                    bat 'docker build -t devops-practice:jenkins-v1 .'
                }
            }
        }

        stage('Verify Docker Image') {
            steps {
                withEnv(['PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin']) {
                    bat 'docker image inspect devops-practice:jenkins-v1 >nul'
                }
            }
        }

        stage('Deploy Test Container') {
            steps {
                withEnv(['PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin']) {
                    bat '''
                        @echo off

                        docker container inspect %TEST_CONTAINER% >nul 2>&1
                        if not errorlevel 1 (
                            echo ERROR: Test container already exists.
                            exit /b 1
                        )

                        powershell -NoProfile -Command "if (Get-NetTCPConnection -LocalPort 8087 -State Listen -ErrorAction SilentlyContinue) { exit 1 }"

                        if errorlevel 1 (
                            echo ERROR: Port 8087 is already in use.
                            exit /b 1
                        )

                        docker run -d --name %TEST_CONTAINER% -p %TEST_PORT%:80 %IMAGE_NAME%

                        if errorlevel 1 (
                            echo ERROR: Test deployment failed.
                            exit /b 1
                        )

                        echo Test container deployed successfully.
                    '''
                }
            }
        }

        stage('Verify Test Container') {
            steps {
                withEnv(['PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin']) {
                    bat '''
                        @echo off

                        for /f %%S in ('docker inspect --format "{{.State.Running}}" %TEST_CONTAINER%') do set "RUNNING=%%S"

                        if not "%RUNNING%"=="true" (
                            echo ERROR: Test container is not running.
                            exit /b 1
                        )

                        echo Test container is running successfully.
                    '''
                }
            }
        }

        stage('HTTP Health Check') {
            steps {
                script {
                    def statusCode = bat(
                        script: '@curl.exe -s -o NUL -w "%%{http_code}" http://localhost:8087',
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

    post {
        success {
            echo 'SUCCESS: New application version passed deployment testing.'
        }

        failure {
            echo 'FAILURE: Deployment testing failed. Existing websites remain untouched.'
        }

        always {
            script {
                withEnv(['PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin']) {
                    bat '''
                        @echo off

                        docker container inspect %TEST_CONTAINER% >nul 2>&1
                        if errorlevel 1 (
                            echo No temporary test container to clean up.
                            exit /b 0
                        )

                        echo Cleaning up temporary test container...
                        docker rm -f %TEST_CONTAINER%

                        if errorlevel 1 (
                            echo ERROR: Temporary container cleanup failed.
                            exit /b 1
                        )
                    '''
                }
            }
        }
    }
}


