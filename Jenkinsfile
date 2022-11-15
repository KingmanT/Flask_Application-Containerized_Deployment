pipeline {
    agent any
        stages {
            stage ('Build'){
                steps {
                    sh '''#!/bin/bash
                    python3 -m venv test3
                    source  test3/bin/activate
                    pip install pip --upgrade
                    pip install -r requirements.txt
                    export FLASK_APP=application
                    flask run &
                    '''
                }
            }
            
            stage ('Test'){
                steps {
                    sh '''#!/bin/bash
                    source test3/bin/activate
                    py.test --verbose --junit-xml  test-reports/results.xml
                    '''
                }
                post {
                    always {
                        junit 'test-reports/results.xml'
                    }
                }
            }

            stage ('Docker_Build'){
                agent{label 'docker_agent'}
                steps {
                withCredentials([string(credentialsId: 'DOCKERHUB_UNAME', variable: 'dockerhub_uname'),
                                    string(credentialsId: 'DOCKERHUB_PASSWD', variable: 'dockerhub_passwd')]) {
                    sh '''#!/bin/bash
                    curl https://raw.githubusercontent.com/KingmanT/Flask_Application-Containerized_Deployment/main/dockerfile > dockerfile
                    docker login --username=${dockerhub_uname} --password=${dockerhub_passwd}
                    docker build -t kingmant/url_shortener:latest .
                    docker push kingmant/url_shortener:latest
                    '''
                    }
                }
            }
        
            stage ('Terraform_Init'){
                agent{label 'terraform_agent'}
                steps {
                    withCredentials([string(credentialsId: 'AWS_ACCESS_KEY', variable: 'aws_access_key'),
                                    string(credentialsId: 'AWS_SECRET_KEY', variable: 'aws_secret_key')]) {
                                        dir('intTerraform') {
                                        sh 'terraform init' 
                                        }
                    }
                }
            }

            stage ('Terraform_Plan'){
                agent{label 'terraform_agent'}
                steps {
                    withCredentials([string(credentialsId: 'AWS_ACCESS_KEY', variable: 'aws_access_key'),
                                    string(credentialsId: 'AWS_SECRET_KEY', variable: 'aws_secret_key')]) {
                                        dir('intTerraform') {
                                        sh 'terraform plan -out plan.tfplan -var="aws_access_key=${aws_access_key}" -var="aws_secret_key=${aws_secret_key}"' 
                                        }
                    }
                }
            }
            
            stage ('Terraform_Apply'){
                agent{label 'terraform_agent'}
                steps {
                    withCredentials([string(credentialsId: 'AWS_ACCESS_KEY', variable: 'aws_access_key'),
                                    string(credentialsId: 'AWS_SECRET_KEY', variable: 'aws_secret_key')]) {
                                        dir('intTerraform') {
                                        sh 'terraform apply plan.tfplan' 
                                        }
                    }
                }
            }

    }
}
