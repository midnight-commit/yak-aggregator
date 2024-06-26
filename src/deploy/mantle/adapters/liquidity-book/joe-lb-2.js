const { deployAdapter, addresses } = require("../../../utils");
const { liquidityBook } = addresses.mantle;

const networkName = "mantle";
const tags = ["lb22"];
const name = "LiquidityBook2Adapter";
const contractName = "LB2Adapter";

const gasEstimate = 1_000_000;
const quoteGasLimit = 600_000;
const factory = liquidityBook.factoryV2;
const args = [name, gasEstimate, quoteGasLimit, factory];

module.exports = deployAdapter(networkName, tags, name, contractName, args);
