package domain

class DeploymentDescriptor(val name: String, val environment: EnvironmentType) {
    fun normalizedName(): String {
        return name.replace('-', '_').replace(' ', '_');
    }

    fun relativeIdPath(): String {
        return normalizedName() + "_" + environment.name
    }
}
