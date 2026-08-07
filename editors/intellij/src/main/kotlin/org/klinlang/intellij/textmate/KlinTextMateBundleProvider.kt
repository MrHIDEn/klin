package org.klinlang.intellij.textmate

import com.intellij.openapi.diagnostic.Logger
import org.jetbrains.plugins.textmate.api.TextMateBundleProvider
import java.net.URI
import java.nio.file.FileSystems
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.nio.file.StandardCopyOption
import kotlin.io.path.createDirectories
import kotlin.io.path.exists

/**
 * Registers the Klin VS Code / TextMate pack shipped under `textmate/klin/`.
 */
class KlinTextMateBundleProvider : TextMateBundleProvider {
    override fun getBundles(): MutableList<TextMateBundleProvider.PluginBundle> {
        val resource = javaClass.classLoader.getResource(BUNDLE_RESOURCE)
            ?: run {
                LOG.warn("Klin TextMate bundle resource missing: $BUNDLE_RESOURCE")
                return mutableListOf()
            }
        val path = resolveBundlePath(resource.toURI())
            ?: return mutableListOf()
        return mutableListOf(TextMateBundleProvider.PluginBundle("klin", path))
    }

    /**
     * TextMate needs a real filesystem path. When the plugin is loaded from a
     * jar, copy the embedded bundle to a cache directory under the system path.
     */
    private fun resolveBundlePath(uri: URI): Path? {
        return try {
            when (uri.scheme) {
                "file" -> Paths.get(uri)
                "jar" -> extractFromJar(uri)
                else -> {
                    LOG.warn("Unsupported TextMate bundle URI scheme: ${uri.scheme}")
                    null
                }
            }
        } catch (e: Exception) {
            LOG.warn("Failed to resolve Klin TextMate bundle", e)
            null
        }
    }

    private fun extractFromJar(uri: URI): Path {
        val cacheRoot = Paths.get(
            System.getProperty("java.io.tmpdir"),
            "klin-intellij-textmate",
            "klin",
        )
        if (!cacheRoot.exists()) {
            cacheRoot.createDirectories()
            FileSystems.newFileSystem(uri, emptyMap<String, Any>()).use { fs ->
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

    companion object {
        private const val BUNDLE_RESOURCE = "textmate/klin"
        private val LOG = Logger.getInstance(KlinTextMateBundleProvider::class.java)
    }
}
