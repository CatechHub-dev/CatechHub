import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension
import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

/**
 * Cartella build globale
 */
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()

rootProject.layout.buildDirectory.value(newBuildDir)

/**
 * Configurazione subprojects
 */
subprojects {

    val newSubprojectBuildDir: Directory =
        newBuildDir.dir(project.name)

    layout.buildDirectory.value(newSubprojectBuildDir)

    evaluationDependsOn(":app")
}

/**
 * Forza compileSdk 36
 * su app + librerie/plugin Flutter
 */
subprojects {

    plugins.withId("com.android.application") {

        extensions.configure<ApplicationExtension> {
            compileSdk = 36
        }
    }

    plugins.withId("com.android.library") {

        extensions.configure<LibraryExtension> {
            compileSdk = 36
        }
    }
}

/**
 * Task clean
 */
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}