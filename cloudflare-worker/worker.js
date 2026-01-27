/**
 * Bible Speak - ESV Audio Proxy Worker
 *
 * Cloudflare Worker를 사용하여 ESV API CORS 문제 해결
 *
 * 배포 방법:
 * 1. https://dash.cloudflare.com 접속
 * 2. Workers & Pages > Create Worker
 * 3. 이 코드 붙여넣기
 * 4. Deploy 클릭
 * 5. 생성된 URL을 AppConfig에 설정
 */

const ESV_API_KEY = '03eafa93305836c02901ca31ee0f10508e950550';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    // ESV Audio proxy: /esv-audio?q=John+3:16
    if (path === '/esv-audio') {
      const reference = url.searchParams.get('q');

      if (!reference) {
        return new Response('Missing q parameter', {
          status: 400,
          headers: corsHeaders,
        });
      }

      try {
        const esvUrl = `https://api.esv.org/v3/passage/audio/?q=${encodeURIComponent(reference)}`;

        const response = await fetch(esvUrl, {
          headers: {
            'Authorization': `Token ${ESV_API_KEY}`,
          },
          redirect: 'follow',
        });

        if (!response.ok) {
          return new Response(`ESV API error: ${response.status}`, {
            status: response.status,
            headers: corsHeaders,
          });
        }

        const audioData = await response.arrayBuffer();

        return new Response(audioData, {
          headers: {
            ...corsHeaders,
            'Content-Type': 'audio/mpeg',
            'Cache-Control': 'public, max-age=86400',
          },
        });
      } catch (error) {
        return new Response(`Error: ${error.message}`, {
          status: 500,
          headers: corsHeaders,
        });
      }
    }

    // ElevenLabs TTS proxy: POST /tts
    if (path === '/tts' && request.method === 'POST') {
      const ELEVENLABS_API_KEY = 'a37eb906f7735ff06fe51303dce546cd36866f40e59be609a8686a13f2b6b1e5';
      const VOICE_ID = '21m00Tcm4TlvDq8ikWAM';

      try {
        const body = await request.json();
        const text = body.text;

        if (!text) {
          return new Response('Missing text', {
            status: 400,
            headers: corsHeaders,
          });
        }

        const response = await fetch(
          `https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}`,
          {
            method: 'POST',
            headers: {
              'xi-api-key': ELEVENLABS_API_KEY,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              text: text,
              model_id: 'eleven_multilingual_v2',
              voice_settings: {
                stability: 0.8,
                similarity_boost: 0.8,
              },
            }),
          }
        );

        if (!response.ok) {
          return new Response(`ElevenLabs error: ${response.status}`, {
            status: response.status,
            headers: corsHeaders,
          });
        }

        const audioData = await response.arrayBuffer();

        return new Response(audioData, {
          headers: {
            ...corsHeaders,
            'Content-Type': 'audio/mpeg',
          },
        });
      } catch (error) {
        return new Response(`Error: ${error.message}`, {
          status: 500,
          headers: corsHeaders,
        });
      }
    }

    return new Response('Bible Speak Audio Proxy\n\nEndpoints:\n- GET /esv-audio?q=John+3:16\n- POST /tts (body: {text: "..."})', {
      headers: { 'Content-Type': 'text/plain', ...corsHeaders },
    });
  },
};
