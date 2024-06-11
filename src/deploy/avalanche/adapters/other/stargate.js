const { deployAdapter } = require("../../../utils");

const networkName = "avalanche";
const tags = ["stargate"];
const name = "StargateAdapter";
const contractName = "StargateAdapter";

const gasEstimate = 150_000;
const args = [gasEstimate];

module.exports = deployAdapter(networkName, tags, name, contractName, args);
