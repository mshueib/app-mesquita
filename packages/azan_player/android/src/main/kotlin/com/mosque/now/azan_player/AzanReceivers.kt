package com.mosque.now.azan_player

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Hora de uma oração: arranca o serviço que toca o Azan. */
class AzanAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val EXTRA_ID = "azan_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, -1)
        val horario = AzanScheduler.porId(context, id) ?: return

        try {
            AzanPlayerService.tocar(context, horario.nome)
        } catch (e: Exception) {
            Log.e("AzanPlayer", "Não foi possível iniciar o Azan", e)
        }

        // Alarmes exactos não se repetem — agenda já o de amanhã.
        AzanScheduler.definirAlarme(context, horario)
    }
}

class AzanBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AzanScheduler.reagendarTodos(context)
    }
}
