const {
  getKstDateParts,
  getKstDayOfYear,
  getKstDateStringDaysAgo,
} = require("./time");

describe("KST date helpers", () => {
  test("rolls over to the next day at KST midnight", () => {
    const beforeMidnight = new Date("2026-01-01T14:59:59.000Z");
    const midnight = new Date("2026-01-01T15:00:00.000Z");

    expect(getKstDateParts(beforeMidnight)).toMatchObject({
      dateString: "2026-01-01",
      hour: 23,
    });
    expect(getKstDateParts(midnight)).toMatchObject({
      dateString: "2026-01-02",
      hour: 0,
    });
  });

  test("computes leap-year day numbers from the KST calendar date", () => {
    expect(getKstDayOfYear(new Date("2028-02-29T03:00:00.000Z"))).toBe(60);
  });

  test("subtracts calendar days without changing the KST boundary", () => {
    const date = new Date("2026-01-08T15:30:00.000Z");
    expect(getKstDateStringDaysAgo(7, date)).toBe("2026-01-02");
  });
});
