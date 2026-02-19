import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.vcs.GitVcsRoot
import projects.AlertaReleaseProject

/*
The settings script is an entry point for defining a TeamCity
project hierarchy. The script should contain a single call to the
project() function with a Project instance or an init function as
an argument.

VcsRoots, BuildTypes, Templates, and subprojects can be
registered inside the project using the vcsRoot(), buildType(),
template(), and subProject() methods respectively.

To debug settings scripts in command-line, run the

    mvnDebug org.jetbrains.teamcity:teamcity-configs-maven-plugin:generate

command and attach your debugger to the port 8000.

To debug in IntelliJ Idea, open the 'Maven Projects' tool window (View
-> Tool Windows -> Maven Projects), find the generate task node
(Plugins -> teamcity-configs -> teamcity-configs:generate), the
'Debug' option is available in the context menu for the task.
*/

version = "2025.11"

project {
    template(GitHubTriggerNotify)

    for (subProject in Configuration.SUBPROJECTS) {
        vcsRoot(GitVcsRoot {
            id = RelativeId(subProject.normalizedName() + "_GitHub")

            name = "${subProject.name} GitHub Repository"

            url = Configuration.VCS_PREFIX + subProject.name
            branch = "refs/heads/main"
            branchSpec = "+:refs/heads/(*)"

            authMethod = password {
                userName = Configuration.GIT_USERNAME
                password = "%" + Configuration.GITHUB_TOKEN_CONFIGURATION_PROPERTY + "%"
            }
        })
    }
    
    vcsRoot(GitVcsRoot {
        id = RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_") + "_GitHub")

        name = Configuration.RELEASE_REPO_NAME + " GitHub Repository"

        url = Configuration.VCS_PREFIX + Configuration.RELEASE_REPO_NAME
        branch = "refs/heads/main"
        branchSpec = "+:refs/heads/(*)"

        authMethod = password {
            userName = Configuration.GIT_USERNAME
            password = "%" + Configuration.GITHUB_TOKEN_CONFIGURATION_PROPERTY + "%"
        }
    })
    vcsRoot(GitVcsRoot {
        id = RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_") + "_DeploymentsGitHub")

        name = Configuration.RELEASE_REPO_NAME + " Deployments GitHub Repository"

        url = Configuration.VCS_PREFIX + Configuration.RELEASE_REPO_NAME
        branch = "refs/heads/main"
        useTagsAsBranches = true
        branchSpec = """
                    +:refs/tags/*
                    -:<default>
                """.trimIndent()

        authMethod = password {
            userName = Configuration.GIT_USERNAME
            password = "%" + Configuration.GITHUB_TOKEN_CONFIGURATION_PROPERTY + "%"
        }
    })

    // Create lume markets projects and their pipelines
    val subProjectsByGroup = Configuration.SUBPROJECTS.groupBy { it.group.name }
    for ((groupName, subprojects) in subProjectsByGroup) {
        subProject {
            id = RelativeId(groupName + "_Group")
            name = groupName

            for (subProject in subprojects) {
                subProject(AlertaProjectFactory.createProject(subProject))
            }
        }
    }

    // Create alerta-release project
    subProject(AlertaReleaseProject.create(Configuration.SUBPROJECTS))

    params {
        param("env.GIT_EMAIL", Configuration.GIT_EMAIL)
        param("env.GIT_USERNAME", Configuration.GIT_USERNAME)
        password("env.GITHUB_TOKEN", "%" + Configuration.GITHUB_TOKEN_CONFIGURATION_PROPERTY + "%")
        param("env.GITHUB_ORG", Configuration.GITHUB_ORG)
        param("env.REPO_PREFIX", Configuration.VCS_PREFIX)
        param("env.RELEASE_REPO_NAME", Configuration.RELEASE_REPO_NAME)
        param("env.VARS_REPO_NAME", Configuration.VARS_REPO_NAME)
        param("env.SUBPROJECT_REPO_NAMES", Configuration.SUBPROJECTS.joinToString(separator = ",") { subProject -> subProject.name })
    }
}
