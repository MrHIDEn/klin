package org.klinlang.intellij.settings

import com.intellij.openapi.options.Configurable
import com.intellij.openapi.options.ConfigurationException
import com.intellij.ui.components.JBLabel
import com.intellij.ui.components.JBTextField
import com.intellij.util.ui.FormBuilder
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
    }

    override fun reset() {
        pathField?.text = KlinSettingsState.getInstance().klinPath
    }

    override fun disposeUIResources() {
        pathField = null
    }
}
