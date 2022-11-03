const { setTestEnv, addresses } = require("../../../utils/test-env");
const { GmxRewardRouter } = addresses.avalanche.other;

describe("YakAdapter - Glp", () => {
  let testEnv;
  let tkns;
  let ate; // adapter-test-env

  before(async () => {
    const networkName = "avalanche";
    const forkBlockNumber = 21898398;
    testEnv = await setTestEnv(networkName, forkBlockNumber);
    tkns = testEnv.supportedTkns;

    const contractName = "GLPAdapter";
    const adapterArgs = ["GLPAdapter", 630_000, GmxRewardRouter];
    ate = await testEnv.setAdapterEnv(contractName, adapterArgs);
  });

  beforeEach(async () => {
    testEnv.updateTrader();
  });

  describe("Query is correct", async () => {
    it("1 WAVAX -> fsGLP", async () => {
      await ate.queryMatches("1000000000000000000", tkns.WAVAX.address, tkns.fsGLP.address, "24418623535918449775");
    });
  });

  describe("Swapping matches query", async () => {
    it("100 WAVAX -> fsGLP", async () => {
      await ate.checkSwapMatchesQuery("100", tkns.WAVAX, tkns.fsGLP);
    });
  });

  // it("Query returns zero if tokens not found", async () => {});

  // it("Gas-estimate is between max-gas-used and 110% max-gas-used", async () => {});
});
