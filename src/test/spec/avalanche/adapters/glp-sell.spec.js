const { forkGlobalNetwork } = require("../../../helpers");
const { setTestEnv, addresses } = require("../../../utils/test-env");
const { GmxRewardRouter } = addresses.avalanche.other;

describe("YakAdapter - Glp", () => {
  let testEnv;
  let tkns;
  let ate; // adapter-test-env

  before(async () => {
    const networkName = "avalanche";
    const forkBlockNumber = 21899061;
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
    it("24 fsGLP -> WAVAX", async () => {
      await ate.queryMatches("24473076323079188400", tkns.fsGLP.address, tkns.WAVAX.address, "1000293638214779576");
    });
  });

  describe("Swapping matches query", async () => {
    it("100 fsGLP -> WAVAX", async () => {
      await ate.checkSwapMatchesQuery("100", tkns.fsGLP, tkns.WAVAX);
    });
  });

  // it("Query returns zero if tokens not found", async () => {});

  // it("Gas-estimate is between max-gas-used and 110% max-gas-used", async () => {});
});
