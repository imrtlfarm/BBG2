// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IElasticLGE.sol";
import "../MockLGE.sol";
import "../lib/Math.sol";

library Discounts {

  /* Internal Functions */
  function _curve(uint term) internal pure returns (uint) {
    uint discount = (35 + (Math.sqrt(term) / 800));
    if(discount < 35) {
      discount = 35;
    }
    else if(discount > 50) {
      discount = 50;
    }
    return Math.min(50, discount);
  } 

}