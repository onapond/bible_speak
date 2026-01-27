const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

// Firebase Admin 초기화
admin.initializeApp();

// ESV API 키 (Firebase Functions 환경변수에서 가져오거나 직접 설정)
const ESV_API_KEY = "03eafa93305836c02901ca31ee0f10508e950550";

// CORS 헤더
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

/**
 * ESV 오디오 프록시 함수
 * 웹에서 CORS 문제를 우회하기 위한 프록시
 *
 * 사용법: /esvAudio?q=John+3:16
 */
exports.esvAudio = functions
  .region("asia-northeast3") // 서울 리전
  .https.onRequest(async (req, res) => {
    // CORS preflight 처리
    if (req.method === "OPTIONS") {
      res.set(corsHeaders);
      res.status(204).send("");
      return;
    }

    // GET 요청만 허용
    if (req.method !== "GET") {
      res.set(corsHeaders);
      res.status(405).send("Method Not Allowed");
      return;
    }

    const reference = req.query.q;

    if (!reference) {
      res.set(corsHeaders);
      res.status(400).send("Missing 'q' parameter (e.g., ?q=John+3:16)");
      return;
    }

    try {
      console.log(`Fetching ESV audio for: ${reference}`);

      const esvUrl = `https://api.esv.org/v3/passage/audio/?q=${encodeURIComponent(reference)}`;

      const response = await fetch(esvUrl, {
        headers: {
          Authorization: `Token ${ESV_API_KEY}`,
        },
        redirect: "follow",
      });

      if (!response.ok) {
        console.error(`ESV API error: ${response.status}`);
        res.set(corsHeaders);
        res.status(response.status).send(`ESV API error: ${response.status}`);
        return;
      }

      // 오디오 데이터 가져오기
      const audioBuffer = await response.buffer();

      // 응답 헤더 설정
      res.set({
        ...corsHeaders,
        "Content-Type": "audio/mpeg",
        "Content-Length": audioBuffer.length,
        "Cache-Control": "public, max-age=86400", // 24시간 캐시
      });

      res.status(200).send(audioBuffer);
    } catch (error) {
      console.error("Error fetching ESV audio:", error);
      res.set(corsHeaders);
      res.status(500).send(`Server error: ${error.message}`);
    }
  });

/**
 * ElevenLabs TTS 프록시 함수 (선택적)
 * 웹에서 TTS 기능 사용을 위한 프록시
 */
exports.elevenLabsTts = functions
  .region("asia-northeast3")
  .https.onRequest(async (req, res) => {
    // CORS preflight
    if (req.method === "OPTIONS") {
      res.set(corsHeaders);
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.set(corsHeaders);
      res.status(405).send("Method Not Allowed");
      return;
    }

    const ELEVENLABS_API_KEY = "a37eb906f7735ff06fe51303dce546cd36866f40e59be609a8686a13f2b6b1e5";
    const VOICE_ID = "21m00Tcm4TlvDq8ikWAM";

    try {
      const {text} = req.body;

      if (!text) {
        res.set(corsHeaders);
        res.status(400).send("Missing 'text' in request body");
        return;
      }

      const response = await fetch(
          `https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}`,
          {
            method: "POST",
            headers: {
              "xi-api-key": ELEVENLABS_API_KEY,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              text: text,
              model_id: "eleven_multilingual_v2",
              voice_settings: {
                stability: 0.8,
                similarity_boost: 0.8,
              },
            }),
          },
      );

      if (!response.ok) {
        res.set(corsHeaders);
        res.status(response.status).send(`ElevenLabs API error: ${response.status}`);
        return;
      }

      const audioBuffer = await response.buffer();

      res.set({
        ...corsHeaders,
        "Content-Type": "audio/mpeg",
        "Content-Length": audioBuffer.length,
      });

      res.status(200).send(audioBuffer);
    } catch (error) {
      console.error("Error with ElevenLabs TTS:", error);
      res.set(corsHeaders);
      res.status(500).send(`Server error: ${error.message}`);
    }
  });

// ============================================================================
// FCM 푸시 알림 함수들
// ============================================================================

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * 사용자의 FCM 토큰 목록 가져오기
 * @param {string} userId - 사용자 ID
 * @returns {Promise<string[]>} FCM 토큰 배열
 */
async function getUserFcmTokens(userId) {
  const tokensSnapshot = await db
    .collection("users")
    .doc(userId)
    .collection("fcmTokens")
    .get();

  return tokensSnapshot.docs.map((doc) => doc.data().token).filter(Boolean);
}

/**
 * 사용자의 알림 설정 가져오기
 * @param {string} userId - 사용자 ID
 * @returns {Promise<Object>} 알림 설정
 */
async function getUserNotificationSettings(userId) {
  const settingsDoc = await db
    .collection("users")
    .doc(userId)
    .collection("settings")
    .doc("notifications")
    .get();

  return settingsDoc.exists ? settingsDoc.data() : { enabled: true };
}

/**
 * FCM 메시지 전송 (여러 토큰으로)
 * @param {string[]} tokens - FCM 토큰 배열
 * @param {Object} notification - 알림 내용
 * @param {Object} data - 추가 데이터
 * @returns {Promise<Object>} 전송 결과
 */
async function sendToTokens(tokens, notification, data) {
  if (!tokens || tokens.length === 0) {
    console.log("No tokens to send");
    return { success: 0, failure: 0 };
  }

  const message = {
    notification,
    data: { ...data, timestamp: Date.now().toString() },
    tokens,
    android: {
      priority: "high",
      notification: {
        channelId: data.priority === "high" ? "bible_speak_high" : "bible_speak_default",
        sound: "default",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await messaging.sendEachForMulticast(message);
    console.log(`Sent: ${response.successCount}, Failed: ${response.failureCount}`);

    // 실패한 토큰 정리 (유효하지 않은 토큰 삭제)
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          if (
            errorCode === "messaging/invalid-registration-token" ||
            errorCode === "messaging/registration-token-not-registered"
          ) {
            failedTokens.push(tokens[idx]);
          }
        }
      });

      // 유효하지 않은 토큰 삭제는 별도 처리 (optional)
      console.log(`Invalid tokens: ${failedTokens.length}`);
    }

    return { success: response.successCount, failure: response.failureCount };
  } catch (error) {
    console.error("Error sending FCM:", error);
    return { success: 0, failure: tokens.length };
  }
}

/**
 * Nudge 알림 전송 (Firestore Trigger)
 * users/{userId}/nudges/{nudgeId} 문서 생성 시 트리거
 */
exports.sendNudgeNotification = functions
  .region("asia-northeast3")
  .firestore.document("users/{userId}/nudges/{nudgeId}")
  .onCreate(async (snap, context) => {
    const nudge = snap.data();
    const { userId } = context.params;

    console.log(`Nudge created for user ${userId}:`, nudge);

    // 알림 설정 확인
    const settings = await getUserNotificationSettings(userId);
    if (!settings.enabled || settings.nudgeEnabled === false) {
      console.log("Nudge notifications disabled for user");
      return null;
    }

    // FCM 토큰 가져오기
    const tokens = await getUserFcmTokens(userId);
    if (tokens.length === 0) {
      console.log("No FCM tokens for user");
      return null;
    }

    // 알림 전송
    const notification = {
      title: `${nudge.fromUserName}님의 격려`,
      body: nudge.message,
    };

    const data = {
      type: "nudge_received",
      priority: "medium",
      nudgeId: context.params.nudgeId,
      fromUserId: nudge.fromUserId,
      groupId: nudge.groupId || "",
    };

    return sendToTokens(tokens, notification, data);
  });

/**
 * 스트릭 경고 알림 (스케줄: 매일 21:00 KST)
 * 오늘 학습하지 않은 사용자에게 알림
 */
exports.sendStreakWarning = functions
  .region("asia-northeast3")
  .pubsub.schedule("0 21 * * *")
  .timeZone("Asia/Seoul")
  .onRun(async (context) => {
    console.log("Running streak warning job at 21:00 KST");

    const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD

    // 오늘 학습하지 않은 사용자 조회 (스트릭이 1 이상인 사용자)
    const usersSnapshot = await db
      .collection("users")
      .where("streak.currentStreak", ">", 0)
      .get();

    let sentCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const streak = userData.streak || {};

      // 이미 오늘 학습했으면 스킵
      if (streak.lastLearnedDate === today) {
        continue;
      }

      // 알림 설정 확인
      const settings = await getUserNotificationSettings(userDoc.id);
      if (!settings.enabled || settings.streakWarningEnabled === false) {
        continue;
      }

      // FCM 토큰 가져오기
      const tokens = await getUserFcmTokens(userDoc.id);
      if (tokens.length === 0) {
        continue;
      }

      // 알림 전송
      const currentStreak = streak.currentStreak || 0;
      const notification = {
        title: "오늘의 암송을 잊지 마세요!",
        body: `${currentStreak}일 연속 스트릭을 유지해보세요. 잠깐이면 충분해요!`,
      };

      const data = {
        type: "streak_warning",
        priority: "high",
        currentStreak: currentStreak.toString(),
      };

      await sendToTokens(tokens, notification, data);
      sentCount++;
    }

    console.log(`Streak warning sent to ${sentCount} users`);
    return null;
  });

/**
 * 아침 만나 알림 (스케줄: 매시간 체크)
 * 사용자별 설정 시간에 맞춰 알림 전송
 */
exports.sendMorningManna = functions
  .region("asia-northeast3")
  .pubsub.schedule("0 * * * *") // 매시간 정각
  .timeZone("Asia/Seoul")
  .onRun(async (context) => {
    const now = new Date();
    const currentHour = now.getHours().toString().padStart(2, "0");
    const targetTime = `${currentHour}:00`;

    console.log(`Running morning manna job for ${targetTime}`);

    // 해당 시간에 알림 설정한 사용자 조회
    const settingsSnapshot = await db
      .collectionGroup("settings")
      .where("morningMannaEnabled", "==", true)
      .where("morningMannaTime", "==", targetTime)
      .get();

    let sentCount = 0;

    for (const settingsDoc of settingsSnapshot.docs) {
      // settings 경로에서 userId 추출: users/{userId}/settings/notifications
      const userId = settingsDoc.ref.parent.parent.id;

      const settings = settingsDoc.data();
      if (!settings.enabled) {
        continue;
      }

      // FCM 토큰 가져오기
      const tokens = await getUserFcmTokens(userId);
      if (tokens.length === 0) {
        continue;
      }

      // 오늘의 만나 메시지 (추후 동적 메시지로 교체 가능)
      const mannaMessages = [
        "주님과 함께하는 아침을 시작하세요.",
        "새벽같이 주를 찾으리로다.",
        "오늘도 말씀과 함께 시작해요.",
        "주의 말씀은 내 발에 등이요, 내 길에 빛이니이다.",
      ];
      const randomMessage = mannaMessages[Math.floor(Math.random() * mannaMessages.length)];

      const notification = {
        title: "아침 만나",
        body: randomMessage,
      };

      const data = {
        type: "morning_manna",
        priority: "high",
      };

      await sendToTokens(tokens, notification, data);
      sentCount++;
    }

    console.log(`Morning manna sent to ${sentCount} users`);
    return null;
  });

/**
 * 반응 배치 알림 (스케줄: 5분마다)
 * 누적된 반응을 모아서 알림
 */
exports.sendReactionBatch = functions
  .region("asia-northeast3")
  .pubsub.schedule("*/5 * * * *") // 5분마다
  .timeZone("Asia/Seoul")
  .onRun(async (context) => {
    console.log("Running reaction batch job");

    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);

    // 최근 5분 내 반응 조회
    const reactionsSnapshot = await db
      .collectionGroup("reactions")
      .where("createdAt", ">", fiveMinutesAgo)
      .where("notified", "==", false)
      .get();

    if (reactionsSnapshot.empty) {
      console.log("No new reactions");
      return null;
    }

    // 사용자별로 반응 그룹화
    const userReactions = {};
    for (const reactionDoc of reactionsSnapshot.docs) {
      const reaction = reactionDoc.data();
      const toUserId = reaction.toUserId;

      if (!userReactions[toUserId]) {
        userReactions[toUserId] = [];
      }
      userReactions[toUserId].push({
        ref: reactionDoc.ref,
        data: reaction,
      });
    }

    let sentCount = 0;

    for (const [userId, reactions] of Object.entries(userReactions)) {
      // 알림 설정 확인
      const settings = await getUserNotificationSettings(userId);
      if (!settings.enabled || settings.reactionEnabled === false) {
        // 알림 비활성화지만 notified 플래그는 업데이트
        for (const r of reactions) {
          await r.ref.update({ notified: true });
        }
        continue;
      }

      // FCM 토큰 가져오기
      const tokens = await getUserFcmTokens(userId);
      if (tokens.length === 0) {
        for (const r of reactions) {
          await r.ref.update({ notified: true });
        }
        continue;
      }

      // 알림 전송
      const reactionCount = reactions.length;
      const notification = {
        title: "새로운 반응이 있어요",
        body: reactionCount === 1
          ? `${reactions[0].data.fromUserName}님이 반응했어요`
          : `${reactions[0].data.fromUserName}님 외 ${reactionCount - 1}명이 반응했어요`,
      };

      const data = {
        type: "reaction_batch",
        priority: "low",
        count: reactionCount.toString(),
      };

      await sendToTokens(tokens, notification, data);

      // notified 플래그 업데이트
      for (const r of reactions) {
        await r.ref.update({ notified: true });
      }

      sentCount++;
    }

    console.log(`Reaction batch sent to ${sentCount} users`);
    return null;
  });

/**
 * 주간 리포트 알림 (스케줄: 일요일 18:00 KST)
 */
exports.sendWeeklySummary = functions
  .region("asia-northeast3")
  .pubsub.schedule("0 18 * * 0") // 일요일 18:00
  .timeZone("Asia/Seoul")
  .onRun(async (context) => {
    console.log("Running weekly summary job");

    // 활성 사용자 조회 (최근 7일 내 학습 기록)
    const weekAgo = new Date();
    weekAgo.setDate(weekAgo.getDate() - 7);
    const weekAgoStr = weekAgo.toISOString().split("T")[0];

    const usersSnapshot = await db
      .collection("users")
      .where("streak.lastLearnedDate", ">=", weekAgoStr)
      .get();

    let sentCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();

      // 알림 설정 확인
      const settings = await getUserNotificationSettings(userDoc.id);
      if (!settings.enabled || settings.weeklySummaryEnabled === false) {
        continue;
      }

      // FCM 토큰 가져오기
      const tokens = await getUserFcmTokens(userDoc.id);
      if (tokens.length === 0) {
        continue;
      }

      // 주간 통계 계산
      const streak = userData.streak || {};
      const weeklyHistory = streak.weeklyHistory || [];
      const activeDays = weeklyHistory.filter((d) => d === true).length;

      const notification = {
        title: "이번 주 암송 리포트",
        body: `이번 주 ${activeDays}일 암송했어요! 현재 ${streak.currentStreak || 0}일 연속 중`,
      };

      const data = {
        type: "weekly_summary",
        priority: "low",
        activeDays: activeDays.toString(),
        currentStreak: (streak.currentStreak || 0).toString(),
      };

      await sendToTokens(tokens, notification, data);
      sentCount++;
    }

    console.log(`Weekly summary sent to ${sentCount} users`);
    return null;
  });
