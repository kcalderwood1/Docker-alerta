package projects

import Configuration
import domain.DeploymentDescriptor
import jetbrains.buildServer.configs.kotlin.BuildTypeSettings
import jetbrains.buildServer.configs.kotlin.Project
import jetbrains.buildServer.configs.kotlin.RelativeId
import jetbrains.buildServer.configs.kotlin.buildFeatures.dockerRegistryConnections
import jetbrains.buildServer.configs.kotlin.buildSteps.ScriptBuildStep
import jetbrains.buildServer.configs.kotlin.buildSteps.script

object AlertaDeploymentProject: Project() {

    fun create(deployments: ArrayList<DeploymentDescriptor>): Project {
        return Project {
            id = RelativeId("deployments")

            name = "Deployments"
            description = "Alerta Deployments"

            val deploymentsByEnvironment = deployments.groupBy { it.environment.name }
            for ((environmentName, environmentDeployments) in deploymentsByEnvironment) {
                subProject {
                    id = RelativeId(environmentName + "_Environment")
                    name = environmentName

                    for (deployment in environmentDeployments) {
                        buildType {
                            id = RelativeId(deployment.relativeIdPath() + "_Deployment")
                            name = "Deploy " + deployment.name
                            type = BuildTypeSettings.Type.DEPLOYMENT

                            description = "Deployment to " + deployment.name + " (" + environmentName + ") environment"

                            vcs {
                                root(RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_") + "_DeploymentsGitHub"))
                            }

                            steps {
                                script {
                                    name = "Validate"
                                    id = "validate"
                                    scriptContent = """
                                        echo "Validating whether chamnge request was approved for this release..."
                                    """.trimIndent()
                                    dockerImage = Configuration.DOCKER_BUILD_IMAGE
                                    dockerImagePlatform = ScriptBuildStep.ImagePlatform.Linux
                                }
                                script {
                                    name = "Deploy"
                                    id = "deploy"
                                    scriptContent = """
                                        echo "Deploying %teamcity.build.branch% version to ${'$'}{DEPLOYMENT_NAME} ${'$'}{DEPLOYMENT_TYPE}..."
                                    """.trimIndent()
                                    dockerImage = Configuration.DOCKER_BUILD_IMAGE
                                    dockerImagePlatform = ScriptBuildStep.ImagePlatform.Linux
                                }
                            }

                            features {
                                dockerRegistryConnections {
                                    loginToRegistry = on {
                                        dockerRegistryId = "PROJECT_EXT_6"
                                    }
                                }
                            }

                            params {
                                param("env.DEPLOYMENT_NAME", deployment.name)
                                param("env.DEPLOYMENT_TYPE", deployment.environment.name)
                            }
                        }
                    }
                }
            }
        }
    }
}
