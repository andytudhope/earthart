// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./Teams.sol";

/*
/* @dev Allows owner to set strict enforcement of payment to mint price.
/* Would then allow buyers to pay _more_ than the mint fee - consider it as a tip
/* when doing a free mint with opt-in pricing.
/* When strict pricing is enabled => msg.value must extactly equal the expected value
/* when strict pricing is disabled => msg.value must be _at least_ the expected value.
/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
/* Pros - can take in gratituity payments during a mint. 
/* Cons - However if you decrease pricing during mint txn settlement 
/* it can result in mints landing who technically now have overpaid.
*/
abstract contract Tippable is Teams {
  bool public strictPricing;

  function setStrictPricing(bool _newStatus) public onlyTeamOrOwner {
    strictPricing = _newStatus;
  }

  // @dev check if msg.value is correct according to pricing enforcement
  // @param _msgValue -> passed in msg.value of tx
  // @param _expectedPrice -> result of getPrice(...args)
  function priceIsRight(uint256 _msgValue, uint256 _expectedPrice) internal view returns (bool) {
    return strictPricing ? 
      _msgValue == _expectedPrice : 
      _msgValue >= _expectedPrice;
  }
}