/**
 * Legacy proxy tombstone.
 *
 * Provider requests now go through authenticated Firebase Functions. Keeping
 * this endpoint active would expose a billable upstream API to anonymous use.
 */
export default {
  async fetch() {
    return new Response(
      JSON.stringify({error: 'This legacy proxy has been retired'}),
      {
        status: 410,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-store',
        },
      },
    );
  },
};
