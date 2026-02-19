import jetbrains.buildServer.configs.kotlin.RelativeId
import jetbrains.buildServer.configs.kotlin.Template
import jetbrains.buildServer.configs.kotlin.buildFeatures.commitStatusPublisher
import jetbrains.buildServer.configs.kotlin.triggers.vcs

object GitHubTriggerNotify : Template({
    RelativeId("GitHubTriggerNotify")
    name = "Template for regular builds"
    description = "Triggered by branch changes, posts results to GitHub"

    triggers {
        vcs {
            id = "TriggerAll"
            branchFilter = """
                   +:*
               """.trimIndent()
        }
    }

    failureConditions {
        executionTimeoutMin = 60
    }

    features {
        commitStatusPublisher {
            id = "NotifyGitHub"
            publisher = github {
                githubUrl = "https://api.github.com"
                authType = personalToken {
                    token = "%" + Configuration.GITHUB_TOKEN_CONFIGURATION_PROPERTY + "%"
                }
            }
        }
    }
})
