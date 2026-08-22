const KST_TIME_ZONE = "Asia/Seoul";

function getKstDateParts(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: KST_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const values = Object.fromEntries(
    parts.filter(({type}) => type !== "literal").map(({type, value}) => [type, value])
  );

  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
    hour: Number(values.hour),
    dateString: `${values.year}-${values.month}-${values.day}`,
  };
}

function getKstDayOfYear(date = new Date()) {
  const {year, month, day} = getKstDateParts(date);
  const start = Date.UTC(year, 0, 0);
  const current = Date.UTC(year, month - 1, day);
  return Math.floor((current - start) / (24 * 60 * 60 * 1000));
}

function getKstDateStringDaysAgo(days, date = new Date()) {
  const shifted = new Date(date.getTime() - days * 24 * 60 * 60 * 1000);
  return getKstDateParts(shifted).dateString;
}

module.exports = {
  KST_TIME_ZONE,
  getKstDateParts,
  getKstDayOfYear,
  getKstDateStringDaysAgo,
};
