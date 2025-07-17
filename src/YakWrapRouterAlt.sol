//       ╟╗                                                                      ╔╬
//       ╞╬╬                                                                    ╬╠╬
//      ╔╣╬╬╬                                                                  ╠╠╠╠╦
//     ╬╬╬╬╬╩                                                                  ╘╠╠╠╠╬
//    ║╬╬╬╬╬                                                                    ╘╠╠╠╠╬
//    ╣╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬      ╒╬╬╬╬╬╬╬╜   ╠╠╬╬╬╬╬╬╬         ╠╬╬╬╬╬╬╬    ╬╬╬╬╬╬╬╬╠╠╠╠╠╠╠╠
//    ╙╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬╕    ╬╬╬╬╬╬╬╜   ╣╠╠╬╬╬╬╬╬╬╬        ╠╬╬╬╬╬╬╬   ╬╬╬╬╬╬╬╬╬╠╠╠╠╠╠╠╩
//     ╙╣╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬  ╔╬╬╬╬╬╬╬    ╔╠╠╠╬╬╬╬╬╬╬╬        ╠╬╬╬╬╬╬╬ ╣╬╬╬╬╬╬╬╬╬╬╬╠╠╠╠╝╙
//               ╘╣╬╬╬╬╬╬╬╬╬╬╬╬╬╬    ╒╠╠╠╬╠╬╩╬╬╬╬╬╬       ╠╬╬╬╬╬╬╬╣╬╬╬╬╬╬╬╙
//                 ╣╬╬╬╬╬╬╬╬╬╬╠╣     ╣╬╠╠╠╬╩ ╚╬╬╬╬╬╬      ╠╬╬╬╬╬╬╬╬╬╬╬╬╬╬
//                  ╣╬╬╬╬╬╬╬╬╬╣     ╣╬╠╠╠╬╬   ╣╬╬╬╬╬╬     ╠╬╬╬╬╬╬╬╬╬╬╬╬╬╬
//                   ╟╬╬╬╬╬╬╬╩      ╬╬╠╠╠╠╬╬╬╬╬╬╬╬╬╬╬     ╠╬╬╬╬╬╬╬╠╬╬╬╬╬╬╬
//                    ╬╬╬╬╬╬╬     ╒╬╬╠╠╬╠╠╬╬╬╬╬╬╬╬╬╬╬╬    ╠╬╬╬╬╬╬╬ ╣╬╬╬╬╬╬╬
//                    ╬╬╬╬╬╬╬     ╬╬╬╠╠╠╠╝╝╝╝╝╝╝╠╬╬╬╬╬╬   ╠╬╬╬╬╬╬╬  ╚╬╬╬╬╬╬╬╬
//                    ╬╬╬╬╬╬╬    ╣╬╬╬╬╠╠╩       ╘╬╬╬╬╬╬╬  ╠╬╬╬╬╬╬╬   ╙╬╬╬╬╬╬╬╬
//

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./interface/IYakRouter.sol";
import "./interface/IWrapper.sol";
import "./lib/Maintainable.sol";
import "./lib/YakViewUtils.sol";

contract YakWrapRouterAlt is Maintainable {
    using FormattedOfferUtils for FormattedOffer;
    using OfferUtils for Offer;

    IYakRouter public router;

    constructor(address _router) {
        setRouter(_router);
    }

    function setRouter(address _router) public onlyMaintainer {
        router = IYakRouter(_router);
    }

    function findBestPathAndWrap(uint256 amountIn, address tokenIn, address wrapper, uint256 maxSteps, uint256 gasPrice)
        external
        view
        returns (FormattedOffer memory bestOffer)
    {
        address[] memory wrapperTokenIn = IWrapper(wrapper).getTokensIn();
        address wrappedToken = IWrapper(wrapper).getWrappedToken();
        uint256 gasEstimate = IWrapper(wrapper).swapGasEstimate();

        if (IWrapper(wrapper).isWhitelisted(tokenIn)) {
            uint256 wrappedAmountOut = IWrapper(wrapper).query(amountIn, tokenIn, wrappedToken);
            bestOffer = formatDirectOffer(tokenIn, wrappedToken, amountIn, wrappedAmountOut, wrapper, gasEstimate);
        }

        for (uint256 i; i < wrapperTokenIn.length; ++i) {
            FormattedOffer memory offer;
            uint256 wrappedAmountOut;
            offer = router.findBestPathWithGas(amountIn, tokenIn, wrapperTokenIn[i], maxSteps, gasPrice);
            wrappedAmountOut =
                IWrapper(wrapper).query(offer.amounts[offer.amounts.length - 1], wrapperTokenIn[i], wrappedToken);

            if (bestOffer.path.length == 0 || wrappedAmountOut > bestOffer.getAmountOut()) {
                offer.addToTail(wrappedAmountOut, wrapper, wrappedToken, gasEstimate);
                bestOffer = offer;
            }
        }
    }

    function unwrapAndFindBestPath(
        uint256 amountIn,
        address tokenOut,
        address wrapper,
        uint256 maxSteps,
        uint256 gasPrice
    ) external view returns (FormattedOffer memory bestOffer) {
        address[] memory wrapperTokenOut = IWrapper(wrapper).getTokensOut();
        address wrappedToken = IWrapper(wrapper).getWrappedToken();
        uint256 gasEstimate = IWrapper(wrapper).swapGasEstimate();

        if (IWrapper(wrapper).isWhitelisted(tokenOut)) {
            uint256 amountOut = IWrapper(wrapper).query(amountIn, wrappedToken, tokenOut);
            bestOffer = formatDirectOffer(wrappedToken, tokenOut, amountIn, amountOut, wrapper, gasEstimate);
        }

        for (uint256 i; i < wrapperTokenOut.length; ++i) {
            uint256 amountOut = IWrapper(wrapper).query(amountIn, wrappedToken, wrapperTokenOut[i]);
            if (amountOut == 0) continue;
            FormattedOffer memory offer;
            offer = router.findBestPathWithGas(amountOut, wrapperTokenOut[i], tokenOut, maxSteps, gasPrice);
            amountOut = offer.getAmountOut();

            if (bestOffer.path.length == 0 || amountOut > bestOffer.getAmountOut()) {
                offer.addToHead(amountIn, wrapper, wrappedToken, gasEstimate);
                bestOffer = offer;
            }
        }
    }

    function formatDirectOffer(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address adapter,
        uint256 gasEstimate
    ) internal pure returns (FormattedOffer memory offer) {
        Offer memory query = OfferUtils.newOffer(amountIn, tokenIn);
        offer = query.format();
        offer.addToTail(amountOut, adapter, tokenOut, gasEstimate);
    }
}
