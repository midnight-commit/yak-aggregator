// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../YakWrapper.sol";
import "../interface/IGmxVault.sol";
import "../interface/IGlpManager.sol";
import "../interface/IGmxRewardRouter.sol";
import "../interface/IERC20.sol";
import "../lib/SafeERC20.sol";

contract GlpWrapper is YakWrapper {
    using SafeERC20 for IERC20;

    uint256 public constant BASIS_POINTS_DIVISOR = 1e4;
    uint256 public constant PRICE_PRECISION = 1e30;

    address public immutable USDG;
    address public immutable GLP;
    address public immutable sGLP;
    address public immutable vault;
    address public immutable rewardRouter;
    address public immutable glpManager;
    address public immutable vaultUtils;

    mapping(address => bool) public isWhitelisted;
    address[] public whitelistedTokens;

    constructor(string memory _name, uint256 _gasEstimate, address _gmxRewardRouter, address _glp, address _sGlp)
        YakWrapper(_name, _gasEstimate)
    {
        address gmxGLPManager = IGmxRewardRouter(_gmxRewardRouter).glpManager();
        address gmxVault = IGlpManager(gmxGLPManager).vault();
        USDG = IGmxVault(gmxVault).usdg();

        address utils;
        try IGmxVault(gmxVault).vaultUtils() returns (IGmxVaultUtils gmxVaultUtils) {
            utils = address(gmxVaultUtils);
        } catch {}
        vaultUtils = utils;

        rewardRouter = _gmxRewardRouter;
        vault = gmxVault;
        glpManager = gmxGLPManager;
        GLP = _glp;
        sGLP = _sGlp;
    }

    function setWhitelistedTokens(address[] memory tokens) public onlyMaintainer {
        for (uint256 i = 0; i < whitelistedTokens.length; i++) {
            isWhitelisted[whitelistedTokens[i]] = false;
        }
        whitelistedTokens = tokens;
        for (uint256 i = 0; i < tokens.length; i++) {
            isWhitelisted[tokens[i]] = true;
        }
    }

    function getTokensIn() external view override returns (address[] memory) {
        return whitelistedTokens;
    }

    function getTokensOut() external view override returns (address[] memory) {
        return whitelistedTokens;
    }

    function getWrappedToken() external view override returns (address) {
        return sGLP;
    }

    function _query(uint256 _amountIn, address _tokenIn, address _tokenOut)
        internal
        view
        override
        returns (uint256 amountOut)
    {
        return (_tokenOut == sGLP) ? _quoteBuyGLP(_tokenIn, _amountIn) : _quoteSellGLP(_tokenOut, _amountIn);
    }

    function _quoteBuyGLP(address _tokenIn, uint256 _amountIn) internal view returns (uint256 amountOut) {
        uint256 aumInUsdg = IGlpManager(glpManager).getAumInUsdg(true);
        uint256 glpSupply = IERC20(GLP).totalSupply();
        uint256 price = IGmxVault(vault).getMinPrice(_tokenIn);
        uint256 usdgAmount = _calculateBuyUsdg(_amountIn, price, _tokenIn);
        amountOut = aumInUsdg == 0 ? usdgAmount : (usdgAmount * glpSupply) / aumInUsdg;
    }

    function _calculateBuyUsdg(uint256 _amountIn, uint256 _price, address _tokenIn)
        internal
        view
        returns (uint256 amountOut)
    {
        amountOut = (_amountIn * _price) / PRICE_PRECISION;
        amountOut = IGmxVault(vault).adjustForDecimals(amountOut, _tokenIn, USDG);
        uint256 feeBasisPoints = _calculateBuyUsdgFeeBasisPoints(_tokenIn, amountOut);
        uint256 amountAfterFees = (_amountIn * (BASIS_POINTS_DIVISOR - feeBasisPoints)) / BASIS_POINTS_DIVISOR;
        amountOut = (amountAfterFees * _price) / PRICE_PRECISION;
        amountOut = IGmxVault(vault).adjustForDecimals(amountOut, _tokenIn, USDG);
    }

    function _quoteSellGLP(address _tokenOut, uint256 _amountIn) internal view returns (uint256 amountOut) {
        uint256 aumInUsdg = IGlpManager(glpManager).getAumInUsdg(false);
        uint256 glpSupply = IERC20(GLP).totalSupply();
        uint256 usdgAmount = (_amountIn * aumInUsdg) / glpSupply;
        uint256 redemptionAmount = IGmxVault(vault).getRedemptionAmount(_tokenOut, usdgAmount);
        uint256 feeBasisPoints = _calculateSellUsdgFeeBasisPoints(_tokenOut, usdgAmount);
        amountOut = (redemptionAmount * (BASIS_POINTS_DIVISOR - feeBasisPoints)) / BASIS_POINTS_DIVISOR;
    }

    function _calculateBuyUsdgFeeBasisPoints(address _tokenIn, uint256 _usdgAmount) internal view returns (uint256) {
        if (vaultUtils > address(0)) {
            return IGmxVaultUtils(vaultUtils).getBuyUsdgFeeBasisPoints(_tokenIn, _usdgAmount);
        }
        return _calculateFeeBasisPoints(_tokenIn, _usdgAmount, true);
    }

    function _calculateSellUsdgFeeBasisPoints(address _tokenOut, uint256 _usdgAmount) internal view returns (uint256) {
        if (vaultUtils > address(0)) {
            return IGmxVaultUtils(vaultUtils).getSellUsdgFeeBasisPoints(_tokenOut, _usdgAmount);
        }
        return _calculateFeeBasisPoints(_tokenOut, _usdgAmount, false);
    }

    function _calculateFeeBasisPoints(address _token, uint256 _usdgAmount, bool _buyUsdg)
        internal
        view
        returns (uint256 feeBasisPoints)
    {
        uint256 mintBurnFeeBps = IGmxVault(vault).mintBurnFeeBasisPoints();
        uint256 taxBps = IGmxVault(vault).taxBasisPoints();
        return IGmxVault(vault).getFeeBasisPoints(_token, _usdgAmount, mintBurnFeeBps, taxBps, _buyUsdg);
    }

    function _swap(uint256 _amountIn, uint256 _amountOut, address _tokenIn, address _tokenOut, address _to)
        internal
        override
    {}

    function swap(uint256 _amountIn, uint256 _amountOut, address _fromToken, address _toToken, address _to)
        external
        override
    {
        uint256 toBalanceBefore = IERC20(_toToken).balanceOf(_to);
        if (_toToken == sGLP) {
            IERC20(_fromToken).approve(glpManager, _amountIn);
            uint256 amount = IGmxRewardRouter(rewardRouter).mintAndStakeGlp(_fromToken, _amountIn, 0, _amountOut);
            _returnTo(sGLP, amount, _to);
        } else {
            IGmxRewardRouter(rewardRouter).unstakeAndRedeemGlp(_toToken, _amountIn, _amountOut, _to);
        }
        uint256 diff = IERC20(_toToken).balanceOf(_to) - toBalanceBefore;
        require(diff >= _amountOut, "Insufficient amount-out");
        emit YakAdapterSwap(_fromToken, _toToken, _amountIn, _amountOut);
    }
}
