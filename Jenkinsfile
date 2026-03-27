pipeline { 
    agent any 
    stages { 
        stage('Checkout') { 
            steps { 
                git 'https://github.com/vijayqadevkraft/dailytask_web.git' 
            } 
        } 
        stage('Create File') { 
            steps { 
                script { 
                    def date = new Date().format('yyyy-MM-dd HH:mm:ss', TimeZone.getTimeZone('UTC')) 
                    writeFile file: 'current_time.txt', text: date 
                } 
            } 
        } 
        stage('Run Deployment Script') { 
            steps { 
                sh 'bash script/deploy.sh' 
            } 
        } 
        stage('Deploy Web Application') { 
            steps { 
                // Add your deployment steps here 
                echo 'Deploying web application...' 
            } 
        } 
    } 
}