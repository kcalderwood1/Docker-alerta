package domain

class ProjectDescriptor(val name: String, val group : ProjectGroup, val type: ProjectType) {
    fun normalizedName(): String {
        return name.replace('-', '_');
    }
}
