package com.mosque.now.azan_player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log

/**
 * Toca o Azan com um MediaPlayer num serviço em primeiro plano.
 *
 * O som de uma notificação é cortado pelo Android assim que se abre a
 * barra de notificações. Tocado aqui, o Azan só pára quando o
 * utilizador toca em "Parar Azan", carrega numa tecla de volume,
 * descarta a notificação, ou o áudio chega ao fim.
 */
class AzanPlayerService : Service() {

    companion object {
        private const val TAG = "AzanPlayer"
        private const val ACAO_TOCAR = "com.mosque.now.azan_player.TOCAR"
        private const val ACAO_PARAR = "com.mosque.now.azan_player.PARAR"
        private const val EXTRA_NOME = "nome"
        private const val CANAL_ID = "azan_player_v1"
        private const val NOTIFICACAO_ID = 4501

        // Ignora eventos de volume logo no arranque (alguns telemóveis
        // emitem um ao pedir o foco de áudio).
        private const val MARGEM_VOLUME_MS = 1500L

        fun tocar(context: Context, nome: String) {
            val intent = Intent(context, AzanPlayerService::class.java)
                .setAction(ACAO_TOCAR)
                .putExtra(EXTRA_NOME, nome)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun parar(context: Context) {
            context.startService(
                Intent(context, AzanPlayerService::class.java).setAction(ACAO_PARAR)
            )
        }
    }

    private var player: MediaPlayer? = null
    private var inicioMs = 0L
    private var receiverVolume: BroadcastReceiver? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACAO_PARAR) {
            pararTudo()
            return START_NOT_STICKY
        }

        val nome = intent?.getStringExtra(EXTRA_NOME) ?: "Salat"
        val audio = getSystemService(AudioManager::class.java)
        val modoNormal = audio.ringerMode == AudioManager.RINGER_MODE_NORMAL

        // startForegroundService obriga a chamar startForeground logo.
        entrarEmPrimeiroPlano(construirNotificacao(nome, aTocar = modoNormal))

        if (!modoNormal) {
            // Silencioso/vibrar: fica só a notificação, sem som.
            sairDePrimeiroPlano(manterNotificacao = true)
            stopSelf()
            return START_NOT_STICKY
        }

        iniciarAudio()
        return START_NOT_STICKY
    }

    private fun iniciarAudio() {
        pararAudio()
        try {
            val uri = Uri.parse("android.resource://$packageName/raw/azan")
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setWakeMode(this@AzanPlayerService, PowerManager.PARTIAL_WAKE_LOCK)
                setDataSource(this@AzanPlayerService, uri)
                setOnCompletionListener { pararTudo() }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "Erro no MediaPlayer: $what/$extra")
                    pararTudo()
                    true
                }
                prepare()
                start()
            }
            inicioMs = SystemClock.elapsedRealtime()
            registarReceiverVolume()
        } catch (e: Exception) {
            Log.e(TAG, "Não foi possível tocar o Azan", e)
            pararTudo()
        }
    }

    /** Qualquer tecla de volume pára o Azan, como num despertador. */
    private fun registarReceiverVolume() {
        if (receiverVolume != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (SystemClock.elapsedRealtime() - inicioMs < MARGEM_VOLUME_MS) return
                pararTudo()
            }
        }
        val filtro = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filtro, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(receiver, filtro)
        }
        receiverVolume = receiver
    }

    private fun pararAudio() {
        receiverVolume?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        receiverVolume = null
        player?.let {
            try { if (it.isPlaying) it.stop() } catch (_: Exception) {}
            it.release()
        }
        player = null
    }

    private fun pararTudo() {
        pararAudio()
        sairDePrimeiroPlano(manterNotificacao = false)
        stopSelf()
    }

    override fun onDestroy() {
        pararAudio()
        super.onDestroy()
    }

    // ---------------- Notificação ----------------

    private fun entrarEmPrimeiroPlano(notificacao: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICACAO_ID,
                notificacao,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICACAO_ID, notificacao)
        }
    }

    private fun sairDePrimeiroPlano(manterNotificacao: Boolean) {
        stopForeground(
            if (manterNotificacao) STOP_FOREGROUND_DETACH else STOP_FOREGROUND_REMOVE
        )
    }

    private fun construirNotificacao(nome: String, aTocar: Boolean): Notification {
        val gestor = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Sem som no canal: o áudio é tocado pelo MediaPlayer.
            val canal = NotificationChannel(
                CANAL_ID,
                "Azan (a tocar)",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Notificação mostrada enquanto o Azan toca"
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            gestor.createNotificationChannel(canal)
        }

        val flagsPi = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val parar = PendingIntent.getService(
            this, 1,
            Intent(this, AzanPlayerService::class.java).setAction(ACAO_PARAR),
            flagsPi,
        )
        val abrirApp = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 2, it, flagsPi)
        }

        val texto = if (aTocar) {
            "Está na hora do Azan.\nPara parar: toque em \"Parar Azan\" ou carregue numa tecla de volume."
        } else {
            "Está na hora do Azan.\nNota: o telemóvel está em modo silencioso ou vibrar, por isso o Azan não tocou."
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CANAL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_MAX)
        }

        builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("🕌 Hora do $nome")
            .setContentText(texto.substringBefore("\n"))
            .setStyle(Notification.BigTextStyle().bigText(texto))
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setShowWhen(true)
            .setContentIntent(abrirApp)

        if (aTocar) {
            builder
                .setOngoing(true)
                // Se o utilizador descartar a notificação, pára também.
                .setDeleteIntent(parar)
                .addAction(Notification.Action.Builder(null, "Parar Azan", parar).build())
        } else {
            builder.setAutoCancel(true)
        }

        return builder.build()
    }
}
