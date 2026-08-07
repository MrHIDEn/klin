package org.klinlang.intellij.lsp

import com.intellij.execution.configurations.GeneralCommandLine
import com.intellij.openapi.project.Project
import com.redhat.devtools.lsp4ij.server.OSProcessStreamConnectionProvider
import org.klinlang.intellij.settings.KlinSettingsState

/**
 * Spawns `klin lsp` (stdio) using the configured executable path.
 */
class KlinLanguageServer(project: Project) : OSProcessStreamConnectionProvider() {
    init {
        val exe = KlinSettingsState.getInstance().klinPath.ifBlank { "klin" }
        val commandLine = GeneralCommandLine(exe, "lsp")
            .withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE)
            .withCharset(Charsets.UTF_8)
        val basePath = project.basePath
        if (basePath != null) {
            commandLine.withWorkDirectory(basePath)
        }
        super.setCommandLine(commandLine)
    }
}
