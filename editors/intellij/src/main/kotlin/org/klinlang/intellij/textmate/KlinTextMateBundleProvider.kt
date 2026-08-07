package org.klinlang.intellij.textmate

import com.intellij.ide.plugins.PluginManagerCore
import com.intellij.openapi.diagnostic.Logger
import com.intellij.openapi.extensions.PluginId
import org.jetbrains.plugins.textmate.api.TextMateBundleProvider
import java.net.URI
import java.nio.file.FileSystems
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.nio.file.StandardCopyOption
import kotlin.io.path.createDirectories
import kotlin.io.path.exists
import kotlin.io.path.notExists

/**
 * Registers the Klin VS Code / TextMate pack shipped under `textmate/klin/`.
 *
 * JAR packaging does not create directory entries, so we resolve via
 * `package.json` (a real file) and extract to a **versioned** cache when needed.
 */
class KlinTextMateBundleProvider : TextMateBundleProvider {
    override fun getBundles(): MutableList<TextMateBundleProvider.PluginBundle> {
        val marker = javaClass.classLoader.getResource("$BUNDLE_RESOURCE/package.json")
            ?: run {
                LOG.warn("Klin TextMate bundle missing: $BUNDLE_RESOURCE/package.json")
                return mutableListOf()
            }
        val bundleRoot = resolveBundleRoot(marker.toURI())
            ?: return mutableListOf()
        return mutableListOf(TextMateBundleProvider.PluginBundle("klin", bundleRoot))
    }

    private fun resolveBundleRoot(packageJsonUri: URI): Path? {
        return try {
            when (packageJsonUri.scheme) {
                "file" -> Paths.get(packageJsonUri).parent
                "jar" -> extractFromJar(packageJsonUri)
                else -> {
                    LOG.warn("Unsupported TextMate bundle URI scheme: ${packageJsonUri.scheme}")
                    null
                }
            }
        } catch (e: Exception) {
            LOG.warn("Failed to resolve Klin TextMate bundle", e)
            null
        }
    }

    private fun extractFromJar(packageJsonUri: URI): Path {
        val version = pluginVersion()
        val cacheRoot = Paths.get(
            System.getProperty("java.io.tmpdir"),
            "klin-intellij-textmate",
            version,
            "klin",
        )
        val marker = cacheRoot.resolve("package.json")
        if (marker.notExists()) {
            if (cacheRoot.exists()) {
                cacheRoot.toFile().deleteRecursively()
            }
            cacheRoot.createDirectories()
            // jar:file:/…/plugin.jar!/textmate/klin/package.json
            val jarUri = URI.create(packageJsonUri.schemeSpecificPart.substringBefore("!"))
            val fsUri = URI.create("jar:$jarUri")
            FileSystems.newFileSystem(fsUri, emptyMap<String, Any>()).use { fs ->
                val root = fs.getPath("/$BUNDLE_RESOURCE")
                Files.walk(root).use { stream ->
                    stream.forEach { source ->
                        val relative = root.relativize(source).toString()
                        if (relative.isEmpty()) return@forEach
                        val target = cacheRoot.resolve(relative)
                        if (Files.isDirectory(source)) {
                            target.createDirectories()
                        } else {
                            target.parent?.createDirectories()
                            Files.copy(source, target, StandardCopyOption.REPLACE_EXISTING)
                        }
                    }
                }
            }
        }
        return cacheRoot
    }

    private fun pluginVersion(): String {
        val plugin = PluginManagerCore.getPlugin(PluginId.getId("org.klin-lang.intellij"))
        return plugin?.version?.ifBlank { null } ?: "dev"
    }

    companion object {
        private const val BUNDLE_RESOURCE = "textmate/klin"
        private val LOG = Logger.getInstance(KlinTextMateBundleProvider::class.java)
    }
}
