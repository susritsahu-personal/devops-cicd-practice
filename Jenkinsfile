
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
                        if errorlevel 1 (
                            echo ERROR: Test deployment failed.
                            exit /b 1
                        )
                    '''
                }
            }
        }

        stage('Verify Test Container') {
            steps {
                withEnv([
                    'PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin'
                ]) {
                    script {
                        def runningStatus = bat(
                            script: '@docker inspect --format "{{.State.Running}}" %TEST_CONTAINER%',
                            returnStdout: true
                        ).trim()

                        echo "Test container running status: ${runningStatus}"

                        if (runningStatus != 'true') {
                            error('ERROR: Test container is not running.')
                        }

                        echo 'Test container verification PASSED.'
                    }
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

                    echo 'Test HTTP health check PASSED.'
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
                        def oldContainerStopped = false
                        def oldContainerRenamed = false

                        bat 'docker container inspect %LIVE_CONTAINER% >nul'

                        def backupExists = bat(
                            script: "docker container inspect ${backupName} >nul 2>&1",
                            returnStatus: true
                        )

                        if (backupExists == 0) {
                            error("Backup container ${backupName} already exists.")
                        }

                        try {
                            echo 'Stopping previous deployment on port 8085.'

                            bat 'docker stop %LIVE_CONTAINER%'
                            oldContainerStopped = true

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
                                error("Live health check failed: ${liveStatus}")
                            }

                            echo 'SUCCESS: New version deployed to port 8085.'
                            echo "Previous deployment preserved as ${backupName}"

                        } catch (Exception deploymentError) {
                            echo "Deployment failed: ${deploymentError.message}"
                            echo 'Attempting to restore the previous deployment.'

                            if (oldContainerRenamed) {
                                def newContainerExists = bat(
                                    script: 'docker container inspect %LIVE_CONTAINER% >nul 2>&1',
                                    returnStatus: true
                                )

                                if (newContainerExists == 0) {
                                    def removeStatus = bat(
                                        script: 'docker rm -f %LIVE_CONTAINER%',
                                        returnStatus: true
                                    )

                                    if (removeStatus != 0) {
                                        echo 'CRITICAL: Could not remove failed new container.'
                                        error('Rollback requires manual intervention.')
                                    }
                                }

                                def renameStatus = bat(
                                    script: "docker rename ${backupName} ${env.LIVE_CONTAINER}",
                                    returnStatus: true
                                )

                                if (renameStatus != 0) {
                                    echo 'CRITICAL: Could not restore original container name.'
                                    error('Rollback requires manual intervention.')
                                }
                            }

                            if (oldContainerStopped) {
                                def restartStatus = bat(
                                    script: 'docker start %LIVE_CONTAINER%',
                                    returnStatus: true
                                )

                                if (restartStatus != 0) {
                                    echo 'CRITICAL: Previous deployment could not restart.'
                                    error('Rollback requires manual intervention.')
                                }

                                echo 'Previous container restarted.'
                            }

                            error('Deployment failed. Rollback attempted; verify port 8085.')
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'SUCCESS: New website version deployed to port 8085.'
        }

        failure {
            echo 'FAILURE: Pipeline failed. Check deployment and rollback logs.'
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
