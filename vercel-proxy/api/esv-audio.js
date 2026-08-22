// Provider requests now use authenticated Firebase Functions. This handler is
// retained only to turn old Vercel routes into an explicit, non-proxying 410.
module.exports = async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  res.status(410).json({error: 'This legacy proxy has been retired'});
};
