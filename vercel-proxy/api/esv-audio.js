const https = require('https');

const ESV_API_KEY = '03eafa93305836c02901ca31ee0f10508e950550';

module.exports = async (req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  const { q } = req.query;

  if (!q) {
    res.status(400).json({ error: 'Missing q parameter' });
    return;
  }

  try {
    const esvUrl = `https://api.esv.org/v3/passage/audio/?q=${encodeURIComponent(q)}`;

    const audioData = await new Promise((resolve, reject) => {
      const options = {
        headers: {
          'Authorization': `Token ${ESV_API_KEY}`,
        },
      };

      https.get(esvUrl, options, (response) => {
        // Handle redirects
        if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
          https.get(response.headers.location, (redirectResponse) => {
            const chunks = [];
            redirectResponse.on('data', (chunk) => chunks.push(chunk));
            redirectResponse.on('end', () => resolve(Buffer.concat(chunks)));
            redirectResponse.on('error', reject);
          }).on('error', reject);
          return;
        }

        if (response.statusCode !== 200) {
          reject(new Error(`ESV API error: ${response.statusCode}`));
          return;
        }

        const chunks = [];
        response.on('data', (chunk) => chunks.push(chunk));
        response.on('end', () => resolve(Buffer.concat(chunks)));
        response.on('error', reject);
      }).on('error', reject);
    });

    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Cache-Control', 'public, max-age=86400');
    res.send(audioData);
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: error.message });
  }
};
