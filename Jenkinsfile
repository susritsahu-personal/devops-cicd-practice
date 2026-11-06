
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
                    bat '''
                        @echo off
                        docker build -t %IMAGE_NAME%:build-%BUILD_NUMBER% .
                        if errorlevel 1 exit /b 1
                    '''
                }
            }
        }

        stage('Verify Docker Image') {
            steps {
                withEnv([
                    'PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin'
                ]) {
                    bat '''
                        @echo off
                        docker image inspect %IMAGE_NAME%:build-%BUILD_NUMBER% >nul
                        if errorlevel 1 exit /b 1
                    '''
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
                    script {
                        def runningStatus = bat(
                            script: '@docker inspect --format "{{.State.Running}}" %TEST_CONTAINER%',
                            returnStdout: true
                        ).trim()

                        echo "Test container running status: ${runningStatus}"

                        if (runningStatus != 'true') {
                            error('Test container is not running.')
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
                            echo 'Stopping previous local deployment.'

                            bat 'docker stop %LIVE_CONTAINER%'
                            oldContainerStopped = true

                            bat "docker rename %LIVE_CONTAINER% ${backupName}"
                            oldContainerRenamed = true

                            echo "Previous container preserved as ${backupName}"

                            bat '''
                                @echo off
                                docker run -d --name %LIVE_CONTAINER% -p %LIVE_PORT%:80 %IMAGE_NAME%:build-%BUILD_NUMBER%
                                if errorlevel 1 exit /b 1
                            '''

                            def liveStatus = bat(
                                script: '@curl.exe -s -o NUL -w "%%{http_code}" http://localhost:8085',
                                returnStdout: true
                            ).trim()

                            echo "Local website HTTP status: ${liveStatus}"

                            if (liveStatus != '200') {
                                error("Local health check failed: ${liveStatus}")
                            }

                            echo 'SUCCESS: Local deployment healthy.'
                            echo "Previous deployment preserved as ${backupName}"

                        } catch (Exception deploymentError) {
                            echo "Deployment failed: ${deploymentError.message}"
                            echo 'Attempting local rollback.'

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
                                        error('CRITICAL: Failed to remove new container.')
                                    }
                                }

                                def renameStatus = bat(
                                    script: "docker rename ${backupName} ${env.LIVE_CONTAINER}",
                                    returnStatus: true
                                )

                                if (renameStatus != 0) {
                                    error('CRITICAL: Failed to restore container name.')
                                }
                            }

                            if (oldContainerStopped) {
                                def restartStatus = bat(
                                    script: 'docker start %LIVE_CONTAINER%',
                                    returnStatus: true
                                )

                                if (restartStatus != 0) {
                                    error('CRITICAL: Previous local container could not restart.')
                                }

                                echo 'Previous local container restarted.'
                            }

                            error('Local deployment failed. Rollback attempted.')
                        }
                    }
                }
            }
        }

        stage('Push Docker Image to Amazon ECR') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'aws-jenkins-access-key-id',
                        variable: 'AWS_ACCESS_KEY_ID'
                    ),
                    string(
                        credentialsId: 'aws-jenkins-secret-access-key',
                        variable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-ecr-repository-uri',
                        variable: 'ECR_REPOSITORY_URI'
                    )
                ]) {
                    withEnv([
                        'AWS_DEFAULT_REGION=ap-south-1',
                        'AWS_EC2_METADATA_DISABLED=true',
                        'PATH+DOCKER=C:\\Users\\Susrit\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin'
                    ]) {
                        powershell '''
                            $ErrorActionPreference = 'Stop'

                            $registry = ($env:ECR_REPOSITORY_URI -split '/')[0]

                            $password = aws ecr get-login-password --region ap-south-1

                            if ($LASTEXITCODE -ne 0 -or
                                [string]::IsNullOrWhiteSpace($password)) {
                                throw 'Unable to obtain ECR login token.'
                            }

                            try {
                                $password | docker login --username AWS --password-stdin $registry

                                if ($LASTEXITCODE -ne 0) {
                                    throw 'Docker login to Amazon ECR failed.'
                                }
                            }
                            finally {
                                $password = $null
                            }

                            Write-Host 'SUCCESS: Docker authenticated with Amazon ECR.'
                        '''

                        bat '''
                            @echo off
                            docker tag %IMAGE_NAME%:build-%BUILD_NUMBER% %ECR_REPOSITORY_URI%:build-%BUILD_NUMBER%
                            if errorlevel 1 exit /b 1

                            docker push %ECR_REPOSITORY_URI%:build-%BUILD_NUMBER%
                            if errorlevel 1 exit /b 1

                            echo SUCCESS: Docker image pushed to Amazon ECR.
                        '''
                    }
                }
            }
        }

        stage('Deploy to AWS EC2 via SSM') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'aws-jenkins-access-key-id',
                        variable: 'AWS_ACCESS_KEY_ID'
                    ),
                    string(
                        credentialsId: 'aws-jenkins-secret-access-key',
                        variable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-ecr-repository-uri',
                        variable: 'ECR_REPOSITORY_URI'
                    ),
                    string(
                        credentialsId: 'aws-ec2-instance-id',
                        variable: 'EC2_INSTANCE_ID'
                    )
                ]) {
                    withEnv([
                        'AWS_DEFAULT_REGION=ap-south-1',
                        'AWS_EC2_METADATA_DISABLED=true'
                    ]) {
                        powershell '''
                            $ErrorActionPreference = 'Stop'

                            $image = "$env:ECR_REPOSITORY_URI`:build-$env:BUILD_NUMBER"

                            # Read Linux script and normalize Windows line endings.
                            $scriptText = Get-Content -Raw 'scripts/deploy-aws.sh'
                            $scriptText = $scriptText.TrimStart([char]0xFEFF)
                            $scriptText = $scriptText -replace "`r`n", "`n"
                            $scriptText = $scriptText -replace "`r", "`n"

                            $encoded = [Convert]::ToBase64String(
                                [Text.Encoding]::UTF8.GetBytes($scriptText)
                            )

                            $remoteCommand = "echo '$encoded' | base64 -d | bash -s -- '$image'"

                            $parameters = @{
                                commands = @($remoteCommand)
                                executionTimeout = @('600')
                            } | ConvertTo-Json -Compress

                            $parametersFile = Join-Path $env:WORKSPACE 'ssm-deploy-parameters.json'

                            try {
                                [IO.File]::WriteAllText(
                                    $parametersFile,
                                    $parameters,
                                    [Text.UTF8Encoding]::new($false)
                                )

                                $commandId = aws ssm send-command `
                                    --instance-ids $env:EC2_INSTANCE_ID `
                                    --document-name AWS-RunShellScript `
                                    --parameters "file://$parametersFile" `
                                    --timeout-seconds 60 `
                                    --query 'Command.CommandId' `
                                    --output text

                                if ($LASTEXITCODE -ne 0 -or
                                    [string]::IsNullOrWhiteSpace($commandId) -or
                                    $commandId.Trim() -eq 'None') {
                                    throw 'SSM command submission failed.'
                                }

                                $commandId = $commandId.Trim()
                                Write-Host "SSM command submitted: $commandId"
                                Write-Host 'Waiting for AWS deployment result...'

                                $completed = $false
                                $lastStatus = 'Unknown'

                                for ($attempt = 1; $attempt -le 150; $attempt++) {

                                    $result = aws ssm get-command-invocation `
                                        --command-id $commandId `
                                        --instance-id $env:EC2_INSTANCE_ID `
                                        --query '[Status,ResponseCode]' `
                                        --output text 2>$null

                                    if ($LASTEXITCODE -ne 0) {
                                        # SSM can briefly report an invocation
                                        # as unavailable after submission.
                                        Start-Sleep -Seconds 5
                                        continue
                                    }

                                    $fields = ("$result".Trim() -split '\\s+')
                                    $status = $fields[0]
                                    $lastStatus = $status

                                    if ($status -eq 'Success') {
                                        if ($fields.Count -lt 2 -or $fields[1] -ne '0') {
                                            throw 'SSM reported success without exit code 0.'
                                        }

                                        $completed = $true
                                        break
                                    }

                                    if ($status -in @(
                                        'Failed',
                                        'Cancelled',
                                        'TimedOut',
                                        'Cancelling'
                                    )) {
                                        throw "AWS deployment command failed: $status"
                                    }

                                    Start-Sleep -Seconds 5
                                }

                                if (-not $completed) {
                                    throw "AWS deployment result not confirmed. Last status: $lastStatus. Inspect SSM command history before retrying."
                                }

                                Write-Host 'SUCCESS: AWS EC2 deployment completed and verified.'
                            }
                            finally {
                                Remove-Item $parametersFile -Force -ErrorAction SilentlyContinue
                            }
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'SUCCESS: Local and AWS deployment stages completed.'
        }

        failure {
            echo 'FAILURE: Check Jenkins logs and AWS SSM command history.'
            echo 'Do not retry an uncertain AWS deployment until its SSM command has finished.'
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
