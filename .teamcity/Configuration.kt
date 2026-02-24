import domain.DeploymentDescriptor
import domain.EnvironmentType
import domain.ProjectDescriptor
import domain.ProjectGroup
import domain.ProjectType

object Configuration {

    const val GITHUB_ORG = "kcalderwood1"
    const val GITHUB_TOKEN_CONFIGURATION_PROPERTY = "KC_GITHUB_TOKEN"
    const val VCS_PREFIX = "https://github.com/${GITHUB_ORG}/"

    const val GIT_EMAIL = "teamcity@lucera.com"
    const val GIT_USERNAME = "teamcity"
    const val DOCKER_BUILD_IMAGE = "repo.prd.lucera.com/lume-release-build:0.2.0"

    // Parent release project
    const val RELEASE_REPO_NAME = "Docker-alerta"
    const val VARS_REPO_NAME = "alerta-vars"
    // Define subprojects
    val SUBPROJECTS: ArrayList<ProjectDescriptor> = arrayListOf(
        ProjectDescriptor("lucera-alerta", ProjectGroup.SubProjects, ProjectType.SHELL)
    )

    // Define deployments
    val DEPLOYMENTS: ArrayList<DeploymentDescriptor> = arrayListOf(
        DeploymentDescriptor("daiwa", EnvironmentType.DEV),
        DeploymentDescriptor("daiwa", EnvironmentType.PROD),
    )
}
