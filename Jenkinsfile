#!groovy
import groovy.json.JsonOutput
import groovy.json.JsonSlurper

/*
Environment variables: These environment variables should be set in Jenkins in: `https://github-demo.ci.cloudbees.com/job/<org name>/configure`:

For deployment purposes:
 - HEROKU_PREVIEW=<your heroku preview app>
 - HEROKU_PREPRODUCTION=<your heroku pre-production app>
 - HEROKU_PRODUCTION=<your heroku production app>

To control which stages you want, please add an environment variable if you want to remove a particular step of the build:
 - DEMO_DISABLE_SONAR=true
 - DEMO_DISABLE_LINT=true
 - DEMO_DISABLE_PREVIEW=true
 - DEMO_DISABLE_PREPROD=true
 - DEMO_DISABLE_PROD=true
 - DEMO_DISABLE_ARTIFACTORY=true
 - DEMO_DISABLE_BINTRAY=true

Please also add the following credentials to the global domain of your organization's folder:
- Heroku API key as secret text with ID 'HEROKU_API_KEY'
- GitHub Token value as secret text with ID 'GITHUB_TOKEN'

*/

podTemplate(
  name: 'test-pod',
  label: 'test-pod',
  containers: [
    containerTemplate(name: 'mvn', image: 'maven:3.3.9-jdk-8-alpine', ttyEnabled: true, command: 'cat')
  ],
  {
    node ('test-pod') {
      container ('mvn') {
        printOptions()
        server = Artifactory.server "artifactory"
        buildInfo = Artifactory.newBuildInfo()
        buildInfo.env.capture = true

        // pull request or feature branch
        if  (env.BRANCH_NAME != 'master') {
            checkout()
            build()
            unitTest()
            // test whether this is a regular branch build or a merged PR build
            if (!isPRMergeBuild()) {
                preview()
                allCodeQualityTests()
            } else {
                // Pull request
                sonarPreview()
            }
        } // master branch / production
        else {
            checkout()
            build()
            allTests()
            preview()
            allCodeQualityTests()
            preProduction()
            manualPromotion()
            production()
        }
      }
    }
  })

def printOptions () {
    echo "====Environment variable configurations===="
    echo sh(script: 'env|sort', returnStdout: true)
}

def isPRMergeBuild() {
    return (env.BRANCH_NAME ==~ /^PR-\d+$/)
}

def sonarPreview() {

    if (env.DEMO_DISABLE_SONAR == "true") {
        return
    }

    stage('Code Quality - SonarQube Preview') {
        prNo = (env.BRANCH_NAME=~/^PR-(\d+)$/)[0][1]
        mvn "org.jacoco:jacoco-maven-plugin:prepare-agent install -Dmaven.test.failure.ignore=true -Pcoverage-per-test"
        withCredentials([[$class: 'StringBinding', credentialsId: 'GITHUB_TOKEN', variable: 'GITHUB_TOKEN']]) {
            githubToken=env.GITHUB_TOKEN
            repoSlug=getRepoSlug()
            withSonarQubeEnv('SonarQube Octodemoapps') {
                mvn "-Dsonar.analysis.mode=preview -Dsonar.github.pullRequest=${prNo} -Dsonar.github.oauth=${githubToken} -Dsonar.github.repository=${repoSlug} -Dsonar.github.endpoint=https://octodemo.com/api/v3/ org.sonarsource.scanner.maven:sonar-maven-plugin:3.2:sonar"
            }
        }
    }
}

def sonarServer() {

    if (env.DEMO_DISABLE_SONAR == "true") {
        return
    }

    stage('Code Quality - SonarQube Server') {
        mvn "org.jacoco:jacoco-maven-plugin:prepare-agent install -Dmaven.test.failure.ignore=true -Pcoverage-per-test"
        withSonarQubeEnv('SonarQube Octodemoapps') {
            mvn "org.sonarsource.scanner.maven:sonar-maven-plugin:3.2:sonar"
        }

        context="sonarqube/qualitygate"
        setBuildStatus ("${context}", 'Checking Sonarqube quality gate', 'PENDING')

        // our new Jenkins instance has a self signed certificate so far
        // SonarQube will not be able to tell the quality gate check to wake up
        // 5 seconds is more than enough for the check to complete before waiting
        sleep 5
        timeout(time: 1, unit: 'MINUTES') { // Just in case something goes wrong, pipeline will be killed after a timeout
            def qg = waitForQualityGate() // Reuse taskId previously collected by withSonarQubeEnv
            if (qg.status != 'OK') {
                setBuildStatus ("${context}", "Sonarqube quality gate fail: ${qg.status}", 'FAILURE')
                error "Pipeline aborted due to quality gate failure: ${qg.status}"
            } else {
                setBuildStatus ("${context}", "Sonarqube quality gate pass: ${qg.status}", 'SUCCESS')
            }
        }
    }
}

def checkout () {
    stage 'Checkout code'
    context="continuous-integration/jenkins/"
    context += isPRMergeBuild()?"pr-merge/checkout":"branch/checkout"
    checkout scm
    setBuildStatus ("${context}", 'Checking out completed', 'SUCCESS')
}

def build () {
    stage 'Build'
    mvn 'clean install -DskipTests=true -Dmaven.javadoc.skip=true -Dcheckstyle.skip=true -B -V'
}


def unitTest() {
    stage 'Unit tests'
    mvn 'test -B -Dmaven.javadoc.skip=true -Dcheckstyle.skip=true'
    if (currentBuild.result == "UNSTABLE") {
        sh "exit 1"
    }
}

def allTests() {
    stage 'All tests'
    // don't skip anything
    mvn 'test -B'
    step([$class: 'JUnitResultArchiver', testResults: '**/target/surefire-reports/TEST-*.xml'])
    if (currentBuild.result == "UNSTABLE") {
        // input "Unit tests are failing, proceed?"
        sh "exit 1"
    }
}

def allCodeQualityTests() {
    sonarServer()
    lintTest()
}

def lintTest() {

    if (env.DEMO_DISABLE_LINT == "true") {
        return
    }

    stage 'Code Quality - Linting'
    context="continuous-integration/jenkins/linting"
    setBuildStatus ("${context}", 'Checking code conventions', 'PENDING')
    lintTestPass = true

    try {
        mvn 'verify -DskipTests=true'
    } catch (err) {
        setBuildStatus ("${context}", 'Some code conventions are broken', 'FAILURE')
        lintTestPass = false
    } finally {
        if (lintTestPass) setBuildStatus ("${context}", 'Code conventions OK', 'SUCCESS')
    }
}

def preview() {

    if (env.DEMO_DISABLE_PREVIEW == "true") {
        return
    }

    stage name: 'Deploy to Preview env', concurrency: 1
    def herokuApp = "${env.HEROKU_PREVIEW}"
    def id = createDeployment(getBranch(), "preview", "Deploying branch to test")
    echo "Deployment ID: ${id}"
    if (id != null) {
        setDeploymentStatus(id, "pending", "https://${herokuApp}.herokuapp.com/", "Pending deployment to test");
        herokuDeploy "${herokuApp}"
        setDeploymentStatus(id, "success", "https://${herokuApp}.herokuapp.com/", "Successfully deployed to test");
    }

    if (env.DEMO_DISABLE_ARTIFACTORY == "true") {
        return
    }
    mvn 'deploy -DskipTests=true'
}

def preProduction() {

    if (env.DEMO_DISABLE_PREPROD == "true") {
        return
    }

    stage name: 'Deploy to Pre-Production', concurrency: 1
    switchSnapshotBuildToRelease()
    herokuDeploy "${env.HEROKU_PREPRODUCTION}"
    if (env.DEMO_DISABLE_ARTIFACTORY != "true") {
        buildAndPublishToArtifactory()
    }

}

def manualPromotion() {

    if (env.DEMO_DISABLE_PROD == "true") {
        return
    }

    // we need a first milestone step so that all jobs entering this stage are tracked an can be aborted if needed
    milestone 1
    // time out manual approval after ten minutes
    timeout(time: 10, unit: 'MINUTES') {
        input message: "Does Pre-Production look good?"
    }
    // this will kill any job which is still in the input step
    milestone 2
}

def production() {

    if (env.DEMO_DISABLE_PROD == "true") {
        return
    }

    stage name: 'Deploy to Production', concurrency: 1
    step([$class: 'ArtifactArchiver', artifacts: '**/target/*.jar', fingerprint: true])
    herokuDeploy "${env.HEROKU_PRODUCTION}"
    def version = getCurrentHerokuReleaseVersion("${env.HEROKU_PRODUCTION}")
    def createdAt = getCurrentHerokuReleaseDate("${env.HEROKU_PRODUCTION}", version)
    echo "Release version: ${version}"
    createRelease(version, createdAt)
    if (env.DEMO_DISABLE_ARTIFACTORY != "true") {
        promoteInArtifactoryAndDistributeToBinTray()
    }
}

def switchSnapshotBuildToRelease() {
    def descriptor = Artifactory.mavenDescriptor()
    descriptor.version = '1.0.0'
    descriptor.pomFile = 'pom.xml'
    descriptor.transform()
}

def buildAndPublishToArtifactory() {
    def rtMaven = Artifactory.newMavenBuild()

    // we like to detect the installed maven version automatically
    rtMaven.tool = null

    // we have to help a bit as we are running in a docker container
    withEnv(["MAVEN_HOME=/usr/share/maven"]) {
      rtMaven.deployer releaseRepo:'libs-release-local', snapshotRepo:'libs-snapshot-local', server: server
      rtMaven.resolver releaseRepo:'libs-release', snapshotRepo:'libs-snapshot', server: server
      rtMaven.run pom: 'pom.xml', goals: 'install', buildInfo: buildInfo
      server.publishBuildInfo buildInfo
    }
}

def promoteBuildInArtifactory() {
    def promotionConfig = [
            // Mandatory parameters
            'buildName'          : buildInfo.name,
            'buildNumber'        : buildInfo.number,
            'targetRepo'         : 'libs-prod-local',

            // Optional parameters
            'comment'            : 'deploying to production',
            'sourceRepo'         : 'libs-release-local',
            'status'             : 'Released',
            'includeDependencies': false,
            'copy'               : true,
            // 'failFast' is true by default.
            // Set it to false, if you don't want the promotion to abort upon receiving the first error.
            'failFast'           : true
    ]

    // Promote build
    server.promote promotionConfig
}

def distributeBuildToBinTray() {
  if (env.DEMO_DISABLE_BINTRAY == "true") {
      return
  }
  def distributionConfig = [
          // Mandatory parameters
          'buildName'             : buildInfo.name,
          'buildNumber'           : buildInfo.number,
          'targetRepo'            : 'reading-time-dist',
          // Optional parameters
          //'publish'               : true, // Default: true. If true, artifacts are published when deployed to Bintray.
          'overrideExistingFiles' : true, // Default: false. If true, Artifactory overwrites builds already existing in the target path in Bintray.
          //'gpgPassphrase'         : 'passphrase', // If specified, Artifactory will GPG sign the build deployed to Bintray and apply the specified passphrase.
          //'async'                 : false, // Default: false. If true, the build will be distributed asynchronously. Errors and warnings may be viewed in the Artifactory log.
          //"sourceRepos"           : ["yum-local"], // An array of local repositories from which build artifacts should be collected.
          //'dryRun'                : false, // Default: false. If true, distribution is only simulated. No files are actually moved.
  ]
  server.distribute distributionConfig
}

def promoteInArtifactoryAndDistributeToBinTray() {
    stage ("Promote in Artifactory and Distribute to BinTray") {
        promoteBuildInArtifactory()
        distributeBuildToBinTray()
    }
}

def mvn(args) {

    // Maven settings.xml file defined with the Jenkins Config File Provider Plugin
    // settings.xml referencing the GitHub Artifactory repositories
    // mavencentral is closer to the Cloudbees Kubernetes cluster as jfrog.io
    // but disabling will break the mvn deploy and artifactory steps
    mavenSettingsConfig = '0e94d6c3-b431-434f-a201-7d7cda7180cb'
    if (env.DEMO_DISABLE_ARTIFACTORY == "true") {
      mavenSettingsConfig = null
    }

    withMaven(
            // Maven installation declared in the Jenkins "Global Tool Configuration"
            // as the docker container does not specify a tool config we go with the default
            // maven: 'Maven 3.x',

            mavenSettingsConfig: mavenSettingsConfig

            // we do not need to set a special local maven repo, take the one from the standard box
            //mavenLocalRepo: '.repository'
    ) {
        // Run the maven build
        sh "mvn $args -Dmaven.test.failure.ignore"
    }
}

def herokuDeploy (herokuApp) {
    withCredentials([[$class: 'StringBinding', credentialsId: 'HEROKU_API_KEY', variable: 'HEROKU_API_KEY']]) {
        mvn "heroku:deploy -DskipTests=true -Dmaven.javadoc.skip=true -B -V -D heroku.appName=${herokuApp}"
    }
}

def getRepoSlug() {
    tokens = "${env.JOB_NAME}".tokenize('/')
    org = tokens[tokens.size()-3]
    repo = tokens[tokens.size()-2]
    return "${org}/${repo}"
}

def getBranch() {
    tokens = "${env.JOB_NAME}".tokenize('/')
    branch = tokens[tokens.size()-1]
    return "${branch}"
}

def createDeployment(ref, environment, description) {
    withCredentials([[$class: 'StringBinding', credentialsId: 'GITHUB_TOKEN', variable: 'GITHUB_TOKEN']]) {
        def payload = JsonOutput.toJson(["ref": "${ref}", "description": "${description}", "environment": "${environment}", "required_contexts": []])
        def apiUrl = "https://octodemo.com/api/v3/repos/${getRepoSlug()}/deployments"
        def response = sh(returnStdout: true, script: "curl -s -H \"Authorization: Token ${env.GITHUB_TOKEN}\" -H \"Accept: application/json\" -H \"Content-type: application/json\" -X POST -d '${payload}' ${apiUrl}").trim()
        def jsonSlurper = new JsonSlurper()
        def data = jsonSlurper.parseText("${response}")
        return data.id
    }
}

void createRelease(tagName, createdAt) {
    withCredentials([[$class: 'StringBinding', credentialsId: 'GITHUB_TOKEN', variable: 'GITHUB_TOKEN']]) {
        def body = "**Created at:** ${createdAt}\n**Deployment job:** [${env.BUILD_NUMBER}](${env.BUILD_URL})\n**Environment:** [${env.HEROKU_PRODUCTION}](https://dashboard.heroku.com/apps/${env.HEROKU_PRODUCTION})"
        def payload = JsonOutput.toJson(["tag_name": "v${tagName}", "name": "${env.HEROKU_PRODUCTION} - v${tagName}", "body": "${body}"])
        def apiUrl = "https://octodemo.com/api/v3/repos/${getRepoSlug()}/releases"
        def response = sh(returnStdout: true, script: "curl -s -H \"Authorization: Token ${env.GITHUB_TOKEN}\" -H \"Accept: application/json\" -H \"Content-type: application/json\" -X POST -d '${payload}' ${apiUrl}").trim()
    }
}

void setDeploymentStatus(deploymentId, state, targetUrl, description) {
    withCredentials([[$class: 'StringBinding', credentialsId: 'GITHUB_TOKEN', variable: 'GITHUB_TOKEN']]) {
        def payload = JsonOutput.toJson(["state": "${state}", "target_url": "${targetUrl}", "description": "${description}"])
        def apiUrl = "https://octodemo.com/api/v3/repos/${getRepoSlug()}/deployments/${deploymentId}/statuses"
        def response = sh(returnStdout: true, script: "curl -s -H \"Authorization: Token ${env.GITHUB_TOKEN}\" -H \"Accept: application/json\" -H \"Content-type: application/json\" -X POST -d '${payload}' ${apiUrl}").trim()
    }
}

void setBuildStatus(context, message, state) {
    // partially hard coded URL because of https://issues.jenkins-ci.org/browse/JENKINS-36961, adjust to your own GitHub instance
    step([
            $class: "GitHubCommitStatusSetter",
            contextSource: [$class: "ManuallyEnteredCommitContextSource", context: context],
            reposSource: [$class: "ManuallyEnteredRepositorySource", url: "https://octodemo.com/${getRepoSlug()}"],
            errorHandlers: [[$class: "ChangingBuildStatusErrorHandler", result: "UNSTABLE"]],
            statusResultSource: [ $class: "ConditionalStatusResultSource", results: [[$class: "AnyBuildResult", message: message, state: state]] ]
    ]);
}

def getCurrentHerokuReleaseVersion(app) {
    withCredentials([[$class: 'StringBinding', credentialsId: 'HEROKU_API_KEY', variable: 'HEROKU_API_KEY']]) {
        def apiUrl = "https://api.heroku.com/apps/${app}/dynos"
        def response = sh(returnStdout: true, script: "curl -s  -H \"Authorization: Bearer ${env.HEROKU_API_KEY}\" -H \"Accept: application/vnd.heroku+json; version=3\" -X GET ${apiUrl}").trim()
        def jsonSlurper = new JsonSlurper()
        def data = jsonSlurper.parseText("${response}")
        return data[0].release.version
    }
}

def getCurrentHerokuReleaseDate(app, version) {
    withCredentials([[$class: 'StringBinding', credentialsId: 'HEROKU_API_KEY', variable: 'HEROKU_API_KEY']]) {
        def apiUrl = "https://api.heroku.com/apps/${app}/releases/${version}"
        def response = sh(returnStdout: true, script: "curl -s  -H \"Authorization: Bearer ${env.HEROKU_API_KEY}\" -H \"Accept: application/vnd.heroku+json; version=3\" -X GET ${apiUrl}").trim()
        def jsonSlurper = new JsonSlurper()
        def data = jsonSlurper.parseText("${response}")
        return data.created_at
    }
}
