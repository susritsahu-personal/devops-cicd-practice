
pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME = 'devops-practice'
        TEST_CONTAINER = 'devops-practice-test'
        LIVE_CONTAINER = 'devops-practice-jenkins'
        TEST_PORT = '8087'
        LIVE_PORT = '8085'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                withEnv([
                    'PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin'
                ]) {
                    bat 'docker build -t %IMAGE_NAME%:build-%BUILD_NUMBER% .'
                }
            }
        }

        stage('Verify Docker Image') {
            steps {
                withEnv([
                    'PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin'
                ]) {
                    bat 'docker image inspect %IMAGE_NAME%:build-%BUILD_NUMBER% >nul'
                }
            }
        }

        stage('Deploy Test Container') {
            steps {
                withEnv([
                    'PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin'
                ]) {
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

                        docker run -d --name %TEST_CONTAINER% -p %TEST_PORT%:80 %IMAGE_NAME%:build-%BUILD_NUMBER%
                        if errorlevel 1 exit /b 1
                    '''
                }
            }
        }

        stage('Verify Test Container') {
            steps {
                withEnv([
                    'PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin'
                ]) {
                    bat '''
                        @echo off
                        docker inspect --format "{{.State.Running}}" %TEST_CONTAINER% | findstr /x true >nul
                        if errorlevel 1 (
                            echo ERROR: Test container is not running.
                            exit /b 1
                        )
                    '''
                }
            }
        }

        stage('Test HTTP Health Check') {
            steps {
                script {
                    def statusCode = bat(
                        script: '@curl.exe -s -o NUL -w "%%{http_code}" http://localhost:8087',
                        returnStdout: true
                    ).trim()

                    echo "Test website HTTP status: ${statusCode}"

                    if (statusCode != '200') {
                        error("Test health check failed: ${statusCode}")
                    }

                    echo 'Test health check PASSED.'
                }
            }
        }

        stage('Deploy to Port 8085') {
            steps {
                script {
                    withEnv([
                        'PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin'
                    ]) {
                        def backupName = "devops-practice-previous-${env.BUILD_NUMBER}"
                        def oldContainerRenamed = false

                        // Check that the expected live container exists.
                        bat 'docker container inspect %LIVE_CONTAINER% >nul'

                        // Do not overwrite an existing backup.
                        def backupExists = bat(
                            script: "docker container inspect ${backupName} >nul 2>&1",
                            returnStatus: true
                        )

                        if (backupExists == 0) {
                            error("Backup container ${backupName} already exists.")
                        }

                        try {
                            echo 'Stopping the existing port 8085 deployment.'

                            bat 'docker stop %LIVE_CONTAINER%'

                            bat "docker rename %LIVE_CONTAINER% ${backupName}"
                            oldContainerRenamed = true

                            echo "Previous container preserved as ${backupName}"

                            bat '''
                                docker run -d --name %LIVE_CONTAINER% -p %LIVE_PORT%:80 %IMAGE_NAME%:build-%BUILD_NUMBER%
                            '''

                            def liveStatus = bat(
                                script: '@curl.exe -s -o NUL -w "%%{http_code}" http://localhost:8085',
                                returnStdout: true
                            ).trim()

                            echo "Live website HTTP status: ${liveStatus}"

                            if (liveStatus != '200') {
                                error("Live deployment health check failed: ${liveStatus}")
                            }

                            echo 'SUCCESS: New version deployed to port 8085.'
                            echo "Previous deployment preserved as ${backupName}"

                        } catch (Exception deploymentError) {
                            echo "Deployment error: ${deploymentError.message}"

                            if (oldContainerRenamed) {
                                echo 'Attempting rollback to the previous deployment.'

                                def removeStatus = bat(
                                    script: 'docker container inspect %LIVE_CONTAINER% >nul 2>&1 && docker rm -f %LIVE_CONTAINER%',
                                    returnStatus: true
                                )

                                def renameStatus = bat(
                                    script: "docker rename ${backupName} ${env.LIVE_CONTAINER}",
                                    returnStatus: true
                                )

                                if (renameStatus == 0) {
                                    def restartStatus = bat(
                                        script: 'docker start %LIVE_CONTAINER%',
                                        returnStatus: true
                                    )

                                    if (restartStatus == 0) {
                                        echo 'Previous deployment restarted. Verify port 8085.'
                                    } else {
                                        echo 'CRITICAL: Rollback restart failed. Manual recovery required.'
                                    }
                                } else {
                                    echo 'CRITICAL: Rollback rename failed. Manual recovery required.'
                                }
                            } else {
                                echo 'Original container was not renamed. Check its running state.'
                            }

                            error('Deployment failed. Review rollback messages above.')
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'SUCCESS: Pipeline completed and live deployment updated.'
        }

        failure {
            echo 'FAILURE: Pipeline failed. Review deployment and rollback logs.'
        }

        always {
            script {
                withEnv([
                    'PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin'
                ]) {
                    bat '''
                        @echo off
                        docker container inspect %TEST_CONTAINER% >nul 2>&1
                        if errorlevel 1 (
                            echo No temporary test container to clean up.
                            exit /b 0
                        )

                        echo Removing temporary test container...
                        docker rm -f %TEST_CONTAINER%
                    '''
                }
            }
        }
    }
}
