package org.klinlang.intellij.settings

import com.intellij.openapi.application.ApplicationManager
import com.intellij.openapi.components.PersistentStateComponent
import com.intellij.openapi.components.Service
import com.intellij.openapi.components.State
import com.intellij.openapi.components.Storage
import com.intellij.util.xmlb.XmlSerializerUtil

@Service(Service.Level.APP)
@State(name = "KlinSettings", storages = [Storage("klin.xml")])
class KlinSettingsState : PersistentStateComponent<KlinSettingsState> {
    /** Executable used to start the language server (default: `klin` on PATH). */
    var klinPath: String = "klin"

    override fun getState(): KlinSettingsState = this

    override fun loadState(state: KlinSettingsState) {
        XmlSerializerUtil.copyBean(state, this)
    }

    companion object {
        fun getInstance(): KlinSettingsState =
            ApplicationManager.getApplication().getService(KlinSettingsState::class.java)
    }
}
