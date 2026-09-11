const { onValueWritten } = require("firebase-functions/v2/database");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

// Nomes legíveis para cada campo que pode mudar no painel de admin.
// Antes disto, o texto da notificação era construído a dividir o
// nome do campo por "_" e assumir que a segunda parte era sempre
// "azan" ou "namaz" — o que produzia notificações sem sentido para
// campos como ano_islamico, nascer_sol ou nissab_valor (ex: "Ano
// Iqamah → 1447").
const CAMPO_LABELS = {
    mes_islamico: "Mês Islâmico",
    ano_islamico: "Ano Islâmico",
    jejum: "Dia do Jejum",
    sehri: "Sehri",
    iftar: "Iftar",
    fajr_azan: "Fajr (Azan)",
    fajr_namaz: "Fajr (Iqamah)",
    dhuhr_azan: "Dhuhr (Azan)",
    dhuhr_namaz: "Dhuhr (Iqamah)",
    asr_azan: "Asr (Azan)",
    asr_namaz: "Asr (Iqamah)",
    maghrib_azan: "Maghrib (Azan)",
    maghrib_namaz: "Maghrib (Iqamah)",
    isha_azan: "Isha (Azan)",
    isha_namaz: "Isha (Iqamah)",
    jummah_azan: "Jummah (Azan)",
    jummah_namaz: "Jummah (Iqamah)",
    suhoor: "Suhoor",
    nascer_sol: "Nascer do Sol",
    ishraq: "Ishraq",
    zawwal: "Zawwal",
    nissab_valor: "Valor do Nissab",
    ultima_data_jejum: "Data do Jejum",
};

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

            const nomeCampo = CAMPO_LABELS[campo] || campo;
            const bodyMsg = `${nomeCampo} → ${valor}`;

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
                // Só chega a quem tem esta mesquita marcada como favorita.
                topic: `mesquita_${event.params.mesquitaId}`,
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
                // Só chega a quem tem esta mesquita marcada como favorita.
                topic: `mesquita_${event.params.mesquitaId}`,
            };

            return await admin.messaging().send(payload);

        } catch (error) {
            console.error("❌ Erro ao enviar aviso:", error);
            return null;
        }
    }
);

exports.notificarAprovacaoMesquita = onValueWritten(
    {
        ref: "/mesquitas/{uid}",
        region: "europe-west1",
    },
    async (event) => {
        try {
            const before = event.data.before;
            const after = event.data.after;

            // Só interessa a criação inicial feita pela aprovação do
            // super-admin — não disparar em cada actualização posterior.
            if (before.exists()) return null;
            if (!after.exists()) return null;

            const dados = after.val();
            const token = dados.fcm_token_admin;
            if (!token) return null;

            console.log("📡 Enviando notificação de aprovação de mesquita");

            await admin.messaging().send({
                token,
                notification: {
                    title: "✅ Mesquita aprovada",
                    body: `A "${dados.nome || "sua mesquita"}" foi aprovada! ` +
                        "Entre para configurar os horários de oração.",
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "mesquita_channel",
                        priority: "max",
                        defaultSound: true,
                        defaultVibrateTimings: true,
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: "default",
                        },
                    },
                },
            });

            // Limpa o token para não voltar a disparar em futuras alterações.
            await event.data.after.ref.update({fcm_token_admin: null});

            return null;
        } catch (error) {
            console.error("❌ Erro ao notificar aprovação de mesquita:", error);
            return null;
        }
    }
);

const MAPUTO_TZ = "Africa/Maputo";
const UM_DIA_MS = 24 * 60 * 60 * 1000;

// Data (yyyy-mm-dd) em hora de Maputo, independente do fuso do servidor.
function dataMaputo(date) {
    return new Intl.DateTimeFormat("en-CA", {
        timeZone: MAPUTO_TZ,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
    }).format(date);
}

// Hora/minuto actuais em Maputo, independente do fuso do servidor.
function horaMaputo(date) {
    const partes = new Intl.DateTimeFormat("en-GB", {
        timeZone: MAPUTO_TZ,
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
    }).formatToParts(date);
    return {
        hour: Number(partes.find((p) => p.type === "hour").value),
        minute: Number(partes.find((p) => p.type === "minute").value),
    };
}

exports.incrementarDiaIslamico = onSchedule(
    {
        schedule: "every 1 hours",
        timeZone: MAPUTO_TZ,
        region: "europe-west1",
    },
    async () => {
        try {
            const snapshot = await admin.database()
                .ref("mesquitas").get();

            if (!snapshot.exists()) return;

            const agora = new Date();
            const hojeStr = dataMaputo(agora);
            const {hour: horaAtual, minute: minutoAtual} = horaMaputo(agora);
            const mesquitas = snapshot.val();

            for (const [id, dados] of Object.entries(mesquitas)) {
                const maghribStr = dados.maghrib_azan;
                if (!maghribStr || !maghribStr.includes(':')) continue;

                const [maghribHour, maghribMin] = maghribStr
                    .split(':').map(Number);

                const jaPassouMaghribHoje =
                    horaAtual > maghribHour ||
                    (horaAtual === maghribHour && minutoAtual >= maghribMin);

                // Dia que já deveria estar contabilizado: hoje, se o Maghrib
                // já passou em Maputo; caso contrário, ainda é "ontem".
                const diaEfetivo = jaPassouMaghribHoje ?
                    hojeStr :
                    dataMaputo(new Date(agora.getTime() - UM_DIA_MS));

                const ultimaData = dados.ultima_data_jejum;

                if (!ultimaData) {
                    // Sem histórico — não inventar quantos dias passaram,
                    // só regista a baseline para as próximas execuções.
                    await admin.database().ref(`mesquitas/${id}`)
                        .update({ultima_data_jejum: diaEfetivo});
                    continue;
                }

                if (ultimaData === diaEfetivo) {
                    console.log(`✅ ${id} já actualizado`);
                    continue;
                }

                // Nº de dias realmente passados desde a última actualização.
                // Isto corrige o contador mesmo que a função tenha ficado
                // dias sem correr (falha, deploy, etc.) — em vez de avançar
                // sempre +1, apanha a diferença toda de uma vez.
                const diffDias = Math.round(
                    (new Date(`${diaEfetivo}T00:00:00Z`) -
                        new Date(`${ultimaData}T00:00:00Z`)) / UM_DIA_MS
                );

                if (diffDias <= 0) continue; // data inconsistente/futura

                const diaAtual = parseInt(dados.jejum) || 0;
                const novoDia = ((diaAtual - 1 + diffDias) % 30) + 1;

                await admin.database()
                    .ref(`mesquitas/${id}`)
                    .update({
                        jejum: novoDia.toString(),
                        ultima_data_jejum: diaEfetivo,
                    });

                console.log(
                    `✅ ${id} — Dia actualizado: ${diaAtual} → ${novoDia} ` +
                    `(+${diffDias}d)`
                );
            }
        } catch (error) {
            console.error("❌ Erro:", error);
        }
    }
);