const { deployUniV2Contract, addresses } = require("../../../utils");
const { univ2 } = addresses.base;

const factory = univ2.factories.swapbased;
const networkName = "base";
const name = "SwapBasedAdapter";
const tags = ["swapbased"];
const fee = 30;
const feeDenominator = 10000;

module.exports = deployUniV2Contract(networkName, tags, name, factory, fee, feeDenominator);
