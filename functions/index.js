const { onValueWritten } = require("firebase-functions/v2/database");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

exports.enviarNotificacaoTrigger = onValueWritten(
    {
        ref: "/app/triggers/{mesquitaId}",
        region: "europe-west1",
    },
    async (event) => {
        try {
            const after = event.data.after;

            if (!after.exists()) return null;

            const data = after.val();

            if (!data) return null;

            const campo = data.campo;
            const valor = data.valor;

            if (!campo || !valor) return null;

            console.log("📡 Enviando notificação FCM");

            const partes = campo.split("_");
            const nomeOracao = partes.length >= 1
                ? partes[0].charAt(0).toUpperCase()
                + partes[0].slice(1)
                : campo;
            const tipoOracao = partes.length >= 2
                ? (partes[1] === "azan"
                    ? "Azan" : "Iqamah")
                : "";
            const bodyMsg = tipoOracao
                ? `${nomeOracao} ${tipoOracao} → ${valor}`
                : `${nomeOracao} → ${valor}`;

            const payload = {
                notification: {
                    title: "🕌 Horário actualizado",
                    body: bodyMsg,
                },
                data: {
                    title: "🕌 Horário actualizado",
                    body: bodyMsg,
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "mesquita_channel",
                        priority: "max",
                        defaultSound: true,
                        defaultVibrateTimings: true,
                        visibility: "public",
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: "default",
                        },
                    },
                },
                topic: "mesquita",
            };

            const result = await admin.messaging().send(payload);

            await event.data.after.ref.remove();

            return result;

        } catch (error) {
            console.error("❌ Erro ao enviar notificação:", error);
            return null;
        }
    }
);

exports.notificarNovoAviso = onValueWritten(
    {
        ref: "/mesquitas/{mesquitaId}/avisos/{avisoId}",
        region: "europe-west1",
    },
    async (event) => {
        try {
            const after = event.data.after;

            if (!after.exists()) return null;

            const before = event.data.before;
            if (before.exists()) return null;

            const aviso = after.val();
            if (!aviso) return null;

            const tipo = aviso.tipo ?? "geral";
            const texto = aviso.texto ?? "";

            if (!texto) return null;

            const titulos = {
                janazah: "🕌 Janazah",
                nikah: "💍 Nikah",
                geral: "📢 Novo Aviso",
            };
            const title = titulos[tipo] ?? "📢 Novo Aviso";

            console.log("📡 Enviando aviso FCM:", tipo, texto);

            const payload = {
                notification: {
                    title: title,
                    body: texto,
                },
                data: {
                    title: title,
                    body: texto,
                    tipo: "aviso",
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "mesquita_channel",
                        priority: "max",
                        defaultSound: true,
                        defaultVibrateTimings: true,
                        visibility: "public",
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: "default",
                        },
                    },
                },
                topic: "mesquita",
            };

            return await admin.messaging().send(payload);

        } catch (error) {
            console.error("❌ Erro ao enviar aviso:", error);
            return null;
        }
    }
);

exports.incrementarDiaIslamico = onSchedule(
    {
        schedule: "every 1 hours",
        timeZone: "Africa/Maputo",
        region: "europe-west1",
    },
    async () => {
        try {
            const snapshot = await admin.database()
                .ref("mesquitas").get();

            if (!snapshot.exists()) return;

            const agora = new Date();
            const hojeStr = agora.toISOString().split('T')[0];
            const mesquitas = snapshot.val();

            for (const [id, dados] of Object.entries(mesquitas)) {
                if (dados.ultima_data_jejum === hojeStr) {
                    console.log(`✅ ${id} já actualizado hoje`);
                    continue;
                }

                const maghribStr = dados.maghrib_azan;
                if (!maghribStr || !maghribStr.includes(':')) continue;

                const [maghribHour, maghribMin] = maghribStr
                    .split(':').map(Number);

                const maghrib = new Date();
                maghrib.setHours(maghribHour, maghribMin, 0, 0);

                if (agora < maghrib) {
                    console.log(`⏳ ${id} — Maghrib ainda não chegou`);
                    continue;
                }

                let diaAtual = parseInt(dados.jejum) || 1;
                let novoDia = diaAtual + 1;
                if (novoDia > 30) novoDia = 1;

                await admin.database()
                    .ref(`mesquitas/${id}`)
                    .update({
                        jejum: novoDia.toString(),
                        ultima_data_jejum: hojeStr,
                    });

                console.log(`✅ ${id} — Dia actualizado: ${novoDia}`);
            }
        } catch (error) {
            console.error("❌ Erro:", error);
        }
    }
);