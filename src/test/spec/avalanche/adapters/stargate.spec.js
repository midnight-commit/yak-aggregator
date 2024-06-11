const { setTestEnv } = require("../../../utils/test-env");

describe("YakAdapter - stargate", () => {
  let testEnv;
  let tkns;
  let ate; // adapter-test-env

  before(async () => {
    const networkName = "avalanche";
    const forkBlockNumber = 46255428;
    testEnv = await setTestEnv(networkName, forkBlockNumber);
    tkns = testEnv.supportedTkns;

    const contractName = "StargateAdapter";
    const adapterArgs = [150_000];
    ate = await testEnv.setAdapterEnv(contractName, adapterArgs);
    await ate.Adapter.addPool("0x5634c4a5FEd09819E3c46D86A965Dd9447d86e47", 6);
  });

  beforeEach(async () => {
    testEnv.updateTrader();
  });

  describe("Swapping matches query", async () => {
    it("100 USDC -> sUSDC", async () => {
      await ate.checkSwapMatchesQuery("100", tkns.USDC, tkns.sUSDC);
    });
    it("100 sUSDC -> USDC", async () => {
      await ate.checkSwapMatchesQuery("100", tkns.sUSDC, tkns.USDC);
    });
  });

  it("Query returns zero if tokens not found", async () => {
    const supportedTkn = tkns.USDC;
    ate.checkQueryReturnsZeroForUnsupportedTkns(supportedTkn);
  });

  it("Gas-estimate is between max-gas-used and 110% max-gas-used", async () => {
    const options = [["1", tkns.USDC, tkns.sUSDC]];
    await ate.checkGasEstimateIsSensible(options);
  });
});
