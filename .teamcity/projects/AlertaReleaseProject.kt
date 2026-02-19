package projects

import domain.ProjectDescriptor
import domain.ProjectGroup
import jetbrains.buildServer.configs.kotlin.FailureAction
import jetbrains.buildServer.configs.kotlin.Project
import jetbrains.buildServer.configs.kotlin.RelativeId
import jetbrains.buildServer.configs.kotlin.buildFeatures.dockerRegistryConnections
import jetbrains.buildServer.configs.kotlin.buildSteps.ScriptBuildStep
import jetbrains.buildServer.configs.kotlin.buildSteps.script
import jetbrains.buildServer.configs.kotlin.triggers.finishBuildTrigger

object AlertaReleaseProject: Project() {

    fun create(subProjects: ArrayList<ProjectDescriptor>): Project {
        return Project {
            id = RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_"))

            name = Configuration.RELEASE_REPO_NAME
            description = "Alerta Platform Project"

            subProject(AlertaDeploymentProject.create(Configuration.DEPLOYMENTS))

            buildType {
                templates(RelativeId("GitHubTriggerNotify"))
                id = RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_") + "_AllBranchBuild")
                name = "Build"

                description = Configuration.RELEASE_REPO_NAME + " regular build for testing a commit"

                vcs {
                    root(RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_") + "_GitHub"))
                }

                steps {
                    script {
                        name = "Build"
                        id = "Build"
                        scriptContent = """
                            ./scripts/build.sh
                        """.trimIndent()
                        dockerImage = Configuration.DOCKER_BUILD_IMAGE
                        dockerImagePlatform = ScriptBuildStep.ImagePlatform.Linux
                    }
                    script {
                        name = "Test"
                        id = "Test"
                        scriptContent = """
                            ./scripts/test.sh
                        """.trimIndent()
                    }
                }
                
                features {
                    dockerRegistryConnections {
                        loginToRegistry = on {
                            dockerRegistryId = "PROJECT_EXT_6"
                        }
                    }
                }
            }

            buildType {
                id = RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_") + "_Release")
                name = "Release"

                description = "Alerta Platform release"

                vcs {
                    root(RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_") + "_GitHub"))

                    branchFilter = """
                    +:<default>
                    +:release*
                """.trimIndent()
                }

                steps {
                    script {
                        id = "simpleRunner"
                        scriptContent = """
                            #!/bin/bash
                            source ./scripts/buildHelpers.sh
                            checkoutAndTagReleaseProject
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

                dependencies {
                    snapshot(RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_") + "_AllBranchBuild")) {
                        onDependencyFailure = FailureAction.CANCEL
                    }
                }
            }

            buildType {
                id = RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_") + "_DependencyUpdate")
                name = "Dependency Version Update"
                description = Configuration.RELEASE_REPO_NAME + " build to update subproject dependency version"

                maxRunningBuildsPerBranch = "*:1"

                vcs {
                    root(RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_") + "_GitHub"))
                }

                steps {
                    script {
                        name = "Build"
                        id = "Build"
                        scriptContent = """
                            ./scripts/dependencyUpdate.sh %SERVICE_NAME% %SERVICE_VERSION% "%SERVICE_BRANCH%"
                        """.trimIndent()
                        dockerImage = Configuration.DOCKER_BUILD_IMAGE
                        dockerImagePlatform = ScriptBuildStep.ImagePlatform.Linux
                    }
                }

                triggers {
                    for (subproject in subProjects) {
                        if (subproject.group == ProjectGroup.SubProjects) {
                            finishBuildTrigger {
                                buildType = RelativeId(subproject.normalizedName() + "_Release").toString()
                                successfulOnly = true
                                branchFilter = """
                                    +:<default>
                                    +:release*
                                """.trimIndent()

                                buildParams {
                                    param("SERVICE_NAME", subproject.normalizedName())
                                    param(
                                        "SERVICE_VERSION",
                                        "%dep.${RelativeId(subproject.normalizedName() + "_Release")}.OUT_SERVICE_VERSION%"
                                    )
                                    param(
                                        "SERVICE_BRANCH",
                                        "%dep.${RelativeId(subproject.normalizedName() + "_Release")}.OUT_SERVICE_BRANCH%"
                                    )
                                }
                            }
                        }
                    }
                }
                
                features {
                    dockerRegistryConnections {
                        loginToRegistry = on {
                            dockerRegistryId = "PROJECT_EXT_6"
                        }
                    }
                }

                dependencies {
                    for (subproject in subProjects) {
                        if (subproject.group == ProjectGroup.SubProjects) {
                            snapshot(RelativeId(subproject.normalizedName() + "_Release")) {
                            }
                        }
                    }
                }
            }

            buildType {
                id = RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_") + "_PrepareRelease")
                name = "Prepare Release Branch"

                description = "Alerta Platform release branch preparation"

                vcs {
                    root(RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_") + "_GitHub"))

                    branchFilter = """
                        +:<default>
                    """.trimIndent()
                }

                steps {
                    script {
                        id = "simpleRunner"
                        scriptContent = """
                            #!/bin/bash
                            source ./scripts/buildHelpers.sh
                            prepareReleaseBranches
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

                dependencies {
                    snapshot(RelativeId(Configuration.RELEASE_REPO_NAME.replace("-", "_") + "_AllBranchBuild")) {
                        onDependencyFailure = FailureAction.CANCEL
                    }
                }
            }

            features {
                feature {
                    id = "PROJECT_EXT_120"
                    type = "deployment-dashboard-config"
                    param("dashboardEnabled", "true")
                    param("projectKey", "env.DEPLOYMENT_NAME")
                    param("refreshSecs", "")
                    param("environments", "DEV,PROD")
                    param("environmentKey", "env.DEPLOYMENT_TYPE")
                    param("multiEnvConfig", "false")
                    param("versionKey", "teamcity.build.branch")
                }
            }
        }
    }
}
