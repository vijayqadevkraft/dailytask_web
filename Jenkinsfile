pipeline { 
    agent any 
    stages { 
        stage('Checkout') { 
            steps { 
                checkout scm
            } 
        } 
        stage('Create File') { 
            steps { 
                script { 
                    def date = new Date().format('yyyy-MM-dd HH:mm:ss', TimeZone.getTimeZone('UTC')) 
                    writeFile file: 'current_time.txt', text: "Deployment time: ${date}"
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
                echo 'Web application deployed successfully.'
            } 
        } 
    } 
}