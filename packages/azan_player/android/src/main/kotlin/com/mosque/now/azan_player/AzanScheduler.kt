package com.mosque.now.azan_player

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar
import java.util.TimeZone

/** Um horário de Azan agendado: id fixo por oração (501–505). */
data class HorarioAzan(val id: Int, val nome: String, val hora: Int, val minuto: Int)

/**
 * Agenda os Azan com o AlarmManager (alarmes exactos, disparam mesmo em
 * modo de poupança). Os horários ficam guardados para poderem ser
 * reagendados depois de reiniciar o telemóvel e para cada alarme se
 * reagendar a si próprio para o dia seguinte.
 */
object AzanScheduler {
    private const val PREFS = "azan_player"
    private const val CHAVE_HORARIOS = "horarios"

    // Mesmo fuso que o resto da app (timezone Africa/Maputo no Dart).
    private val FUSO: TimeZone = TimeZone.getTimeZone("Africa/Maputo")

    fun agendar(context: Context, horario: HorarioAzan) {
        guardar(context, lerTodos(context).filter { it.id != horario.id } + horario)
        definirAlarme(context, horario)
    }

    /** Cancela os alarmes pendentes — não pára um Azan que já esteja a tocar. */
    fun cancelarTodos(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        for (horario in lerTodos(context)) {
            alarmManager.cancel(pendingIntent(context, horario))
        }
        guardar(context, emptyList())
    }

    fun reagendarTodos(context: Context) {
        lerTodos(context).forEach { definirAlarme(context, it) }
    }

    fun porId(context: Context, id: Int): HorarioAzan? =
        lerTodos(context).firstOrNull { it.id == id }

    fun definirAlarme(context: Context, horario: HorarioAzan) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val quando = proximaOcorrencia(horario.hora, horario.minuto)
        val pi = pendingIntent(context, horario)

        val podeExacto = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
        if (podeExacto) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, quando, pi)
        } else {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, quando, pi)
        }
    }

    private fun proximaOcorrencia(hora: Int, minuto: Int): Long {
        val agora = Calendar.getInstance(FUSO)
        val alvo = (agora.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, hora)
            set(Calendar.MINUTE, minuto)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (!alvo.after(agora)) alvo.add(Calendar.DAY_OF_YEAR, 1)
        return alvo.timeInMillis
    }

    private fun pendingIntent(context: Context, horario: HorarioAzan): PendingIntent {
        val intent = Intent(context, AzanAlarmReceiver::class.java)
            .putExtra(AzanAlarmReceiver.EXTRA_ID, horario.id)
        return PendingIntent.getBroadcast(
            context,
            horario.id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // Formato simples "id|nome|hora|minuto;..." — os nomes das orações
    // (Fajr, Dhuhr, ...) nunca têm "|" nem ";".
    private fun lerTodos(context: Context): List<HorarioAzan> {
        val texto = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(CHAVE_HORARIOS, "") ?: ""
        return texto.split(";").filter { it.isNotBlank() }.mapNotNull { linha ->
            val p = linha.split("|")
            if (p.size != 4) return@mapNotNull null
            HorarioAzan(
                p[0].toIntOrNull() ?: return@mapNotNull null,
                p[1],
                p[2].toIntOrNull() ?: return@mapNotNull null,
                p[3].toIntOrNull() ?: return@mapNotNull null,
            )
        }
    }

    private fun guardar(context: Context, horarios: List<HorarioAzan>) {
        val texto = horarios.joinToString(";") { "${it.id}|${it.nome}|${it.hora}|${it.minuto}" }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(CHAVE_HORARIOS, texto).apply()
    }
}
