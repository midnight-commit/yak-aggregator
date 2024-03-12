const { deployAdapter, addresses } = require('../../../utils')
const { crvusd_usdc } = addresses.arbitrum.curve

const networkName = 'arbitrum'
const tags = [ 'curve', 'crvusd_usdc']
const name = 'Curve2crvUsdUsdc'
const contractName = 'CurvePlain128Adapter'

const gasEstimate = 320_000
const pool = crvusd_usdc
const args = [ name, pool, gasEstimate ]

module.exports = deployAdapter(networkName, tags, name, contractName, args)