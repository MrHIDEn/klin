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
 * JAR packaging may omit directory resource entries, so we resolve via
 * `package.json` and extract to a **versioned** cache when needed.
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

    private fun extractFromJar(packageJsonUri: URI): Path? {
        synchronized(EXTRACT_LOCK) {
            val version = pluginVersion()
            val cacheRoot = Paths.get(
                System.getProperty("java.io.tmpdir"),
                "klin-intellij-textmate",
                version,
                "klin",
            )
            val grammar = cacheRoot.resolve("syntaxes/klin.tmLanguage.json")
            if (cacheRoot.resolve("package.json").exists() && grammar.exists()) {
                return cacheRoot
            }

            val staging = cacheRoot.resolveSibling("${cacheRoot.fileName}.extracting")
            if (staging.exists()) {
                staging.toFile().deleteRecursively()
            }
            staging.createDirectories()

            return try {
                val jarUri = URI.create(packageJsonUri.schemeSpecificPart.substringBefore("!"))
                val fsUri = URI.create("jar:$jarUri")
                FileSystems.newFileSystem(fsUri, emptyMap<String, Any>()).use { fs ->
                    val root = fs.getPath("/$BUNDLE_RESOURCE")
                    Files.walk(root).use { stream ->
                        stream.forEach { source ->
                            val relative = root.relativize(source).toString()
                            if (relative.isEmpty()) return@forEach
                            val target = staging.resolve(relative)
                            if (Files.isDirectory(source)) {
                                target.createDirectories()
                            } else {
                                target.parent?.createDirectories()
                                Files.copy(source, target, StandardCopyOption.REPLACE_EXISTING)
                            }
                        }
                    }
                }
                if (staging.resolve("package.json").notExists() ||
                    staging.resolve("syntaxes/klin.tmLanguage.json").notExists()
                ) {
                    LOG.warn("Incomplete Klin TextMate extract under $staging")
                    staging.toFile().deleteRecursively()
                    return null
                }
                if (cacheRoot.exists()) {
                    cacheRoot.toFile().deleteRecursively()
                }
                Files.move(staging, cacheRoot)
                cacheRoot
            } catch (e: Exception) {
                LOG.warn("Failed to extract Klin TextMate bundle", e)
                staging.toFile().deleteRecursively()
                null
            }
        }
    }

    private fun pluginVersion(): String {
        val plugin = PluginManagerCore.getPlugin(PluginId.getId("org.klin-lang.intellij"))
        return plugin?.version?.ifBlank { null } ?: "dev"
    }

    companion object {
        private const val BUNDLE_RESOURCE = "textmate/klin"
        private val EXTRACT_LOCK = Any()
        private val LOG = Logger.getInstance(KlinTextMateBundleProvider::class.java)
    }
}
