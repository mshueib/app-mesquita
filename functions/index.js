const { onValueWritten } = require("firebase-functions/v2/database");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const nodemailer = require("nodemailer");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

// ---------------------------------------------------------------------
// Login por PIN verificado no servidor.
//
// Antes, a app lia o PIN da base de dados (que era de leitura pública) e
// comparava-o no telemóvel. Agora os PINs vivem em /privado (nenhum
// cliente lhes acede) e esta função, se o PIN estiver certo, dá ao
// utilizador (sessão anónima) um custom claim que as regras verificam:
//   superAdmin: true           → gere tudo e aprova mesquitas
//   mesquita: "<id>"           → gere só essa mesquita
// ---------------------------------------------------------------------
const JANELA_MS = 15 * 60 * 1000;
const MAX_FALHAS_POR_UTILIZADOR = 5;
// Sessões anónimas são baratas — um limite por PIN evita que alguém
// contorne o limite acima criando uma sessão nova a cada tentativa.
const MAX_FALHAS_POR_PIN = 30;

function pinsIguais(a, b) {
    const x = Buffer.from(String(a).trim());
    const y = Buffer.from(String(b).trim());
    return x.length === y.length && crypto.timingSafeEqual(x, y);
}

async function registarFalha(ref, agora) {
    await ref.transaction((t) => {
        if (!t || agora - (t.desde || 0) > JANELA_MS) {
            return {n: 1, desde: agora};
        }
        return {n: (t.n || 0) + 1, desde: t.desde};
    });
}

async function bloqueado(ref, agora, maximo) {
    const t = (await ref.get()).val();
    return !!t && agora - (t.desde || 0) <= JANELA_MS && (t.n || 0) >= maximo;
}

exports.loginComPin = onCall({region: "europe-west1"}, async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
        throw new HttpsError("unauthenticated", "Sessão em falta.");
    }

    const {pin, tipo, mesquitaId} = request.data || {};
    if (typeof pin !== "string" || !pin.trim() ||
        !["admin", "superAdmin"].includes(tipo)) {
        throw new HttpsError("invalid-argument", "Pedido inválido.");
    }
    if (tipo === "admin" &&
        (typeof mesquitaId !== "string" ||
            !/^[A-Za-z0-9_-]{1,128}$/.test(mesquitaId))) {
        throw new HttpsError("invalid-argument", "Mesquita inválida.");
    }

    const db = admin.database();
    const alvo = tipo === "superAdmin" ?
        "super_admin" : `mesquita_${mesquitaId}`;
    const refUtilizador = db.ref(`privado/tentativas/utilizador/${uid}`);
    const refPin = db.ref(`privado/tentativas/pin/${alvo}`);
    const agora = Date.now();

    if (await bloqueado(refUtilizador, agora, MAX_FALHAS_POR_UTILIZADOR) ||
        await bloqueado(refPin, agora, MAX_FALHAS_POR_PIN)) {
        throw new HttpsError("resource-exhausted",
            "Demasiadas tentativas. Tente novamente mais tarde.");
    }

    const caminho = tipo === "superAdmin" ?
        "privado/pins/super_admin" : `privado/pins/mesquitas/${mesquitaId}`;
    const correcto = (await db.ref(caminho).get()).val();

    if (correcto === null || !pinsIguais(correcto, pin)) {
        await registarFalha(refUtilizador, agora);
        await registarFalha(refPin, agora);
        return {ok: false};
    }

    await refUtilizador.remove();

    const utilizador = await admin.auth().getUser(uid);
    const claims = {...(utilizador.customClaims || {})};
    if (tipo === "superAdmin") {
        claims.superAdmin = true;
    } else {
        claims.mesquita = mesquitaId;
    }
    await admin.auth().setCustomUserClaims(uid, claims);

    return {ok: true};
});

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

// Credenciais do email que envia os avisos de aprovação. Guardadas no
// Secret Manager — nunca no código. Definir uma vez com:
//   firebase functions:secrets:set SMTP_USER   (ex: o Gmail do MosqueNow)
//   firebase functions:secrets:set SMTP_PASS   (palavra-passe de aplicação)
const SMTP_USER = defineSecret("SMTP_USER");
const SMTP_PASS = defineSecret("SMTP_PASS");

function escaparHtml(texto) {
    return String(texto).replace(/[&<>"']/g, (c) => ({
        "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;",
    })[c]);
}

async function enviarEmailAprovacao(para, nomeMesquita) {
    const transporte = nodemailer.createTransport({
        host: "smtp.gmail.com",
        port: 465,
        secure: true,
        auth: {user: SMTP_USER.value(), pass: SMTP_PASS.value()},
    });

    const nome = escaparHtml(nomeMesquita);
    await transporte.sendMail({
        from: `"MosqueNow" <${SMTP_USER.value()}>`,
        to: para,
        subject: `✅ ${nomeMesquita} foi aprovada no MosqueNow`,
        text:
            "Assalamu alaikum,\n\n" +
            `A mesquita "${nomeMesquita}" foi aprovada no MosqueNow.\n\n` +
            "Para configurar os horários de oração e publicar avisos:\n" +
            "1. Abra a app MosqueNow\n" +
            "2. Vá a Mais → Admin\n" +
            "3. Toque em \"Sou administrador de uma mesquita registada\"\n" +
            "4. Entre com esta mesma conta Google\n\n" +
            "Jazakallahu khairan,\nEquipa MosqueNow",
        html:
            "<p>Assalamu alaikum,</p>" +
            `<p>A mesquita <b>${nome}</b> foi aprovada no MosqueNow. ✅</p>` +
            "<p>Para configurar os horários de oração e publicar avisos:</p>" +
            "<ol><li>Abra a app MosqueNow</li><li>Vá a <b>Mais → Admin</b></li>" +
            "<li>Toque em <b>“Sou administrador de uma mesquita registada”</b></li>" +
            "<li>Entre com <b>esta mesma conta Google</b></li></ol>" +
            "<p>Jazakallahu khairan,<br>Equipa MosqueNow</p>",
    });
}

exports.notificarAprovacaoMesquita = onValueWritten(
    {
        ref: "/mesquitas/{uid}",
        region: "europe-west1",
        secrets: [SMTP_USER, SMTP_PASS],
    },
    async (event) => {
        const before = event.data.before;
        const after = event.data.after;

        // Só interessa a criação inicial feita pela aprovação do
        // super-admin — não disparar em cada actualização posterior.
        if (before.exists() || !after.exists()) return null;

        const dados = after.val() || {};
        // Só mesquitas vindas do registo (têm admin_uid) — não as criadas
        // à mão na consola.
        if (!dados.admin_uid) return null;

        const nomeMesquita = dados.nome || "A sua mesquita";

        // 1) Notificação push no telemóvel onde foi feito o registo.
        //    Independente do email: uma falha num não impede o outro.
        const token = dados.fcm_token_admin;
        if (token) {
            try {
                await admin.messaging().send({
                    token,
                    notification: {
                        title: "✅ Mesquita aprovada",
                        body: `A "${nomeMesquita}" foi aprovada! ` +
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
                    apns: {payload: {aps: {sound: "default"}}},
                });
            } catch (error) {
                console.error("❌ Push de aprovação falhou:", error);
            }
            // Limpa o token (deixa de ser necessário e não fica público).
            await after.ref.update({fcm_token_admin: null});
        }

        // 2) Email para a conta Google usada no registo (a mesma com que o
        //    admin vai entrar). O email escrito no formulário é o recurso.
        try {
            let para = null;
            try {
                para = (await admin.auth().getUser(event.params.uid)).email;
            } catch (_) {
                // utilizador apagado — usa o email do formulário
            }
            para = para || dados.email_admin;
            if (!para) {
                console.warn(`Sem email para avisar ${event.params.uid}`);
                return null;
            }
            await enviarEmailAprovacao(para, nomeMesquita);
            console.log(`📧 Email de aprovação enviado (${event.params.uid})`);
        } catch (error) {
            console.error("❌ Email de aprovação falhou:", error);
        }
        return null;
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