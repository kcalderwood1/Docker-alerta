import domain.ProjectDescriptor
import domain.ProjectType
import jetbrains.buildServer.configs.kotlin.Project
import projects.AlertaShellProject

object AlertaProjectFactory {

    fun createProject(subProject: ProjectDescriptor): Project {
        return when(subProject.type) {
            ProjectType.SHELL -> AlertaShellProject.create(subProject)
            ProjectType.MAVEN -> TODO()
            ProjectType.GRADLE -> TODO()
            ProjectType.NODE -> TODO()
        }
    }
}
