package org.klinlang.intellij.settings

import com.intellij.openapi.options.Configurable
import com.intellij.openapi.options.ConfigurationException
import com.intellij.openapi.project.ProjectManager
import com.intellij.ui.components.JBLabel
import com.intellij.ui.components.JBTextField
import com.intellij.util.ui.FormBuilder
import com.redhat.devtools.lsp4ij.LanguageServerManager
import javax.swing.JComponent
import javax.swing.JPanel

class KlinConfigurable : Configurable {
    private var pathField: JBTextField? = null

    override fun getDisplayName(): String = "Klin"

    override fun createComponent(): JComponent {
        val field = JBTextField()
        pathField = field
        return FormBuilder.createFormBuilder()
            .addLabeledComponent(JBLabel("Klin executable:"), field, 1, false)
            .addComponentFillVertically(JPanel(), 0)
            .panel
    }

    override fun isModified(): Boolean {
        val settings = KlinSettingsState.getInstance()
        return pathField?.text?.trim() != settings.klinPath
    }

    @Throws(ConfigurationException::class)
    override fun apply() {
        val path = pathField?.text?.trim().orEmpty()
        if (path.isEmpty()) {
            throw ConfigurationException("Klin executable path cannot be empty")
        }
        KlinSettingsState.getInstance().klinPath = path
        // Rebuild the command line by restarting LSP4IJ servers in open projects.
        // Default stop() also disables the server; keep it enabled so start() works.
        val stopOptions = LanguageServerManager.StopOptions().apply {
            setWillDisable(false)
        }
        val startOptions = LanguageServerManager.StartOptions().apply {
            setForceStart(true)
        }
        for (project in ProjectManager.getInstance().openProjects) {
            if (project.isDisposed) continue
            val manager = LanguageServerManager.getInstance(project)
            manager.stop(SERVER_ID, stopOptions)
            manager.start(SERVER_ID, startOptions)
        }
    }

    override fun reset() {
        pathField?.text = KlinSettingsState.getInstance().klinPath
    }

    override fun disposeUIResources() {
        pathField = null
    }

    companion object {
        private const val SERVER_ID = "klinLsp"
    }
}
