package com.mosque.now.azan_player

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Registado automaticamente em todos os motores Flutter (incluindo o
 * do handler de FCM em segundo plano), por isso o Azan pode ser
 * reagendado mesmo com a app fechada.
 */
class AzanPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var canal: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        canal = MethodChannel(binding.binaryMessenger, "com.mosque.now/azan_player")
        canal.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        canal.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "agendar" -> {
                val id = call.argument<Int>("id")
                val nome = call.argument<String>("nome")
                val hora = call.argument<Int>("hora")
                val minuto = call.argument<Int>("minuto")
                if (id == null || nome == null || hora == null || minuto == null) {
                    result.error("ARGS", "id, nome, hora e minuto são obrigatórios", null)
                    return
                }
                AzanScheduler.agendar(context, HorarioAzan(id, nome, hora, minuto))
                result.success(null)
            }
            "cancelarTodos" -> {
                AzanScheduler.cancelarTodos(context)
                result.success(null)
            }
            "testar" -> {
                AzanPlayerService.tocar(context, call.argument<String>("nome") ?: "Teste")
                result.success(null)
            }
            "parar" -> {
                AzanPlayerService.parar(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
